CREATE OR REPLACE PACKAGE BODY it.PAS_TRA IS
  v_fec_actual           ge_calendarios.fec_actual%TYPE;
  v_nro_registro         NUMBER(18) := 0; -- contador de numeros de registros de operaciones
  v_cod_entidad          ge_par_generales.cod_entidad%TYPE := pag_gen.fu_obt_cod_entidad;
  v_cod_per_entidad      ge_par_generales.cod_persona%TYPE := fug_obt_per_entidad;
  v_can_salarios         ge_par_dinamicos.val_parametro%TYPE := fug_obt_pardinamico('SIB_TRA_CAN_MTO_MINIMO');
  v_tip_entidad          ge_par_generales.tip_entidad%TYPE := fug_obt_tip_entidad;
  rp_stdet               sb_transferencias_det%ROWTYPE;
  v_cod_persona          ba_personas.cod_persona%TYPE;
  v_hora                 ge_movimientos.hora%TYPE;
  v_fecha                ge_movimientos.fecha%TYPE;
  v_cod_usuario          ge_movimientos.cod_usuario%TYPE;
  v_val_parametro        ge_par_dinamicos.val_parametro%TYPE;
  v_nro_cuenta           ge_movimientos.nro_cuenta%TYPE;
  v_cod_per_ordenante    ba_personas.cod_persona%TYPE;
  v_cod_per_beneficiario ba_personas.cod_persona%TYPE;
  v_sal_minimo           pr_parametros.sal_min_vigente%TYPE;
  v_mto_minimo           pr_parametros.sal_min_vigente%TYPE;
  v_concepto             ge_movimientos.concepto%TYPE;
  v_cod_mon_local        ge_par_generales.cod_mon_local%TYPE := pag_gen.fu_obt_mon_local;
  v_lugar                varchar2(1000) := null;
  --v_cod_swi_patrocinador sb_transferencias_det.cod_swi_bco_beneficiario%type;
  v_swi_banco ge_par_dinamicos.val_parametro%TYPE := fug_obt_pardinamico('SIB_TRA_SWI_BANCO');

  PROCEDURE lp_act_tot_registro(p_fec_periodo sb_crc_operaciones.fec_periodo%TYPE) IS
    v_tot_registro NUMBER(21);
  BEGIN
    SELECT COUNT(*)
    INTO v_tot_registro
    FROM sb_transferencias_det
    WHERE fecha = p_fec_periodo;
    UPDATE sb_transferencias
    SET tot_registro = nvl(v_tot_registro, 0)
    WHERE fec_periodo = p_fec_periodo;
    IF SQL%NOTFOUND THEN
      INSERT INTO sb_transferencias
        (nom_referencia, fec_periodo, cod_entidad, tot_registro)
      VALUES
        ('TRANSFERS', p_fec_periodo, v_cod_entidad, nvl(v_tot_registro, 0));
    END IF;
  END;

  FUNCTION fu_obt_mon_iso(p_cod_moneda IN ba_monedas.cod_moneda%TYPE)
    RETURN VARCHAR2 IS
    v_cod_mon_iso ba_monedas.cod_mon_iso%TYPE;
  BEGIN
    SELECT cod_mon_iso
    INTO v_cod_mon_iso
    FROM ba_monedas
    WHERE cod_moneda = p_cod_moneda;
    RETURN v_cod_mon_iso;
  EXCEPTION
    WHEN no_data_found THEN
      RETURN NULL;
  END;

  PROCEDURE lp_eli_dat_registro IS
  BEGIN
    rp_stdet.fecha                     := NULL;
    rp_stdet.nom_referencia            := NULL;
    rp_stdet.nro_registro              := NULL;
    rp_stdet.nro_formulario            := NULL;
    rp_stdet.cod_oficina               := NULL;
    rp_stdet.tip_movimiento            := NULL;
    rp_stdet.nro_operacion             := NULL;
    rp_stdet.cod_mon_iso               := NULL;
    rp_stdet.fec_operacion             := NULL;
    rp_stdet.tip_doc_ordenante         := NULL;
    rp_stdet.nro_doc_ordenante         := NULL;
    rp_stdet.nro_cta_ordenante         := NULL;
    rp_stdet.monto                     := NULL;
    rp_stdet.val_conversion            := NULL;
    rp_stdet.cod_swi_bco_intermediario := NULL;
    rp_stdet.cod_pai_iso_origen        := NULL;
    rp_stdet.des_ciu_iso_origen        := NULL;
    rp_stdet.cod_swi_bco_beneficiario  := NULL;
    rp_stdet.cod_pai_iso_destino       := NULL;
    rp_stdet.des_ciu_iso_destino       := NULL;
    rp_stdet.tip_fondo                 := NULL;
    rp_stdet.tip_motivo                := NULL;
    rp_stdet.tip_financiacion          := NULL;
    rp_stdet.tip_doc_transportadora    := NULL;
    rp_stdet.nro_doc_transportadora    := NULL;
    rp_stdet.tip_doc_beneficiario      := NULL;
    rp_stdet.nro_doc_beneficiario      := NULL;
    rp_stdet.nro_cta_beneficiario      := NULL;
    rp_stdet.autorizado                := NULL;
    rp_stdet.cod_modulo                := NULL;
    rp_stdet.cod_modalidad             := NULL;
    rp_stdet.tip_operacion             := NULL;
  END;

  FUNCTION fu_obt_ori_fondo(p_nro_documento IN ba_personas.nro_documento%TYPE)
    RETURN VARCHAR2 IS
    v_tip_fondo    VARCHAR2(2);
    v_sec_contable ge_clientes.cod_sec_contable%TYPE;
    v_tipo         ba_personas.tipo%TYPE;
    v_cod_persona  ba_personas.cod_persona%TYPE;
  BEGIN
    SELECT cod_sec_contable, b.tipo, v_cod_persona
    INTO v_sec_contable, v_tipo, v_cod_persona
    FROM ge_clientes g, ba_personas b
    WHERE b.cod_persona = g.cod_persona
    AND b.nro_documento = p_nro_documento
    group by cod_sec_contable, b.tipo;

    IF v_cod_per_entidad = v_cod_persona THEN
      v_tip_fondo := 4;
    ELSIF v_tipo = 'F' THEN
      --fisica
      IF v_sec_contable = 'N' THEN
        v_tip_fondo := 1;
      END IF;
    ELSE
      -- jurídica
      IF v_sec_contable = 'N'
         OR v_sec_contable = 'F' THEN
        v_tip_fondo := 2;
      ELSIF v_sec_contable = 'I'
            OR v_sec_contable = 'P' THEN
        v_tip_fondo := 3;
      END IF;
    END IF;

    RETURN v_tip_fondo;
  EXCEPTION
    WHEN no_data_found THEN
      RETURN NULL;
    WHEN OTHERS THEN
      RETURN NULL;
  END;
  FUNCTION fu_obt_mot_autoriza(p_tip_motivo IN lc_transferencias.tip_motivo%TYPE)
    RETURN VARCHAR2 IS
    v_autorizado lc_transferencias.autorizado%TYPE;
  BEGIN
    SELECT ltrim(rtrim(val_maximo))
    INTO v_autorizado
    FROM ba_cod_referencias
    WHERE dominio = 'TRA_MOT_AUTORIZA'
    AND val_minimo = p_tip_motivo;
    RETURN v_autorizado;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 'N';
  END;

  PROCEDURE lp_ins_transferencias_det(rp_stdet sb_transferencias_det%ROWTYPE) IS
    v_tip_fondo            sb_transferencias_det.tip_fondo%TYPE;
    v_tip_motivo           sb_transferencias_det.tip_motivo%TYPE;
    v_tip_financiacion     sb_transferencias_det.tip_financiacion%TYPE;
    v_nro_doc_beneficiario sb_transferencias_det.nro_doc_beneficiario%TYPE;
    v_nro_doc_ordenante    sb_transferencias_det.Nro_Doc_Ordenante%TYPE;
    v_tip_doc_beneficiario sb_transferencias_det.tip_doc_beneficiario%TYPE;
    v_tip_doc_ordenante    sb_transferencias_det.tip_doc_ordenante%TYPE;
  BEGIN
    IF v_cod_entidad = 1028 THEN
      v_tip_fondo := nvl(fu_obt_ori_fondo(rp_stdet.nro_doc_ordenante), rp_stdet.tip_fondo);
    ELSE
      v_tip_fondo := rp_stdet.tip_fondo;
    END IF;
    IF rp_stdet.tip_financiacion = 0 THEN
      v_tip_financiacion := 1;
    ELSE
      v_tip_financiacion := rp_stdet.tip_financiacion;
    END IF;
    IF rp_stdet.tip_motivo IN (0, 22) THEN
      v_tip_motivo := 1;
    ELSE
      v_tip_motivo := rp_stdet.tip_motivo;
    END IF;
    IF v_cod_entidad = 6004 THEN
      IF rp_stdet.tip_doc_beneficiario = 'RUC' THEN
        IF rp_stdet.nro_doc_beneficiario IS NOT NULL THEN
          IF instr(rp_stdet.nro_doc_beneficiario, '-') = 0 THEN
            v_nro_doc_beneficiario := rp_stdet.nro_doc_beneficiario || '-' ||
                                      fue_obt_ruc_dig_verificador(rp_stdet.nro_doc_beneficiario);
          ELSE
            v_nro_doc_beneficiario := rp_stdet.nro_doc_beneficiario;
          END IF;
        ELSE
          v_nro_doc_beneficiario := NULL;
        END IF;
      ELSE
        v_nro_doc_beneficiario := rp_stdet.nro_doc_beneficiario;
      END IF;
      IF rp_stdet.tip_doc_ordenante = 'RUC' THEN
        IF rp_stdet.nro_doc_ordenante IS NOT NULL THEN
          IF instr(rp_stdet.nro_doc_ordenante, '-') = 0 THEN
            v_nro_doc_ordenante := rp_stdet.nro_doc_ordenante || '-' ||
                                   fue_obt_ruc_dig_verificador(rp_stdet.nro_doc_ordenante);
          ELSE
            v_nro_doc_ordenante := rp_stdet.nro_doc_ordenante;
          END IF;
        ELSE
          v_nro_doc_ordenante := NULL;
        END IF;
      ELSE
        v_nro_doc_ordenante := rp_stdet.nro_doc_ordenante;
      END IF;
    ELSE
      v_nro_doc_beneficiario := rp_stdet.nro_doc_beneficiario;
      v_nro_doc_ordenante    := rp_stdet.nro_doc_ordenante;
    END IF;

    --BSEVOCORE-904 Tipos de documentos BCP - Equivalente SIB_TIP_DOC_BCP
    IF rp_stdet.tip_doc_ordenante IS NOT NULL THEN
      v_tip_doc_ordenante := fue_obt_val_max_refcodes('SIB_TIP_DOC_BCP', rp_stdet.tip_doc_ordenante);
    ELSE
      v_tip_doc_ordenante := rp_stdet.tip_doc_ordenante;
    END IF;

    IF rp_stdet.tip_doc_beneficiario IS NOT NULL THEN
      v_tip_doc_beneficiario := fue_obt_val_max_refcodes('SIB_TIP_DOC_BCP', rp_stdet.tip_doc_beneficiario);
    ELSE
      v_tip_doc_beneficiario := rp_stdet.tip_doc_beneficiario;
    END IF;
    --Fin BSEVOCORE-904

    INSERT INTO sb_transferencias_det
      (fecha,
       nom_referencia,
       nro_registro,
       nro_formulario,
       cod_oficina,
       tip_movimiento,
       nro_operacion,
       cod_mon_iso,
       fec_operacion,
       tip_doc_ordenante,
       nro_doc_ordenante,
       nro_cta_ordenante,
       monto,
       val_conversion,
       cod_swi_bco_intermediario,
       cod_pai_iso_origen,
       des_ciu_iso_origen,
       cod_swi_bco_beneficiario,
       cod_pai_iso_destino,
       des_ciu_iso_destino,
       tip_fondo,
       tip_motivo,
       tip_financiacion,
       tip_doc_transportadora,
       nro_doc_transportadora,
       tip_doc_beneficiario,
       nro_doc_beneficiario,
       nro_cta_beneficiario,
       autorizado,
       cod_modulo,
       cod_modalidad,
       tip_operacion)
    VALUES
      (rp_stdet.fecha,
       'TRANSFERS',
       rp_stdet.nro_registro,
       '013',
       nvl(fug_obt_pardinamico('COD_OFI_NO_HAB_BCP', NULL, NULL, NULL, rp_stdet.cod_oficina), rp_stdet.cod_oficina),
       rp_stdet.tip_movimiento,
       rp_stdet.nro_operacion,
       fu_obt_mon_iso(rp_stdet.cod_mon_iso),
       rp_stdet.fec_operacion,
       v_tip_doc_ordenante /*rp_stdet.tip_doc_ordenante*/,
       v_nro_doc_ordenante,
       nvl(rp_stdet.nro_cta_ordenante, 0),
       rp_stdet.monto,
       nvl(rp_stdet.val_conversion, 1),
       rp_stdet.cod_swi_bco_intermediario,
       rp_stdet.cod_pai_iso_origen,
       rp_stdet.des_ciu_iso_origen,
       rp_stdet.cod_swi_bco_beneficiario,
       rp_stdet.cod_pai_iso_destino,
       rp_stdet.des_ciu_iso_destino,
       v_tip_fondo,
       v_tip_motivo,
       v_tip_financiacion,
       rp_stdet.tip_doc_transportadora,
       rp_stdet.nro_doc_transportadora, /*rp_stdet.tip_doc_beneficiario*/
       v_tip_doc_beneficiario,
       v_nro_doc_beneficiario,
       nvl(rp_stdet.nro_cta_beneficiario, 0),
       nvl(rp_stdet.autorizado, 'N'),
       rp_stdet.cod_modulo,
       rp_stdet.cod_modalidad,
       rp_stdet.tip_operacion);
    -- limpiamos los datos del regitro.
    lp_eli_dat_registro;
  END;

  PROCEDURE lp_obt_cod_swift(p_cod_banco       IN ge_bancos.cod_banco%TYPE DEFAULT NULL,
                             p_cod_bco_central IN ge_bancos.cod_bco_central%TYPE DEFAULT NULL,
                             p_cod_swift       OUT ge_bancos.cod_swift%TYPE) IS
  BEGIN
    IF p_cod_bco_central IS NOT NULL
       AND v_tip_entidad = 'F' THEN
      SELECT cod_swift
      INTO p_cod_swift
      FROM gv_snp_participantes
      WHERE cod_persona = v_cod_per_entidad;
    ELSE
      IF p_cod_bco_central IS NOT NULL THEN
        SELECT nvl(rpad(cod_swift, 11, 'X'), cod_aba)
        INTO p_cod_swift
        FROM ge_bancos
        WHERE (cod_banco = p_cod_banco OR p_cod_banco IS NULL)
        AND (cod_bco_central = p_cod_bco_central OR
              p_cod_bco_central IS NULL);
      ELSE
        SELECT nvl(rpad(cod_swift, 11, 'X'), cod_aba)
        INTO p_cod_swift
        FROM ge_bancos
        WHERE (cod_banco = p_cod_banco OR p_cod_banco IS NULL)
        AND (cod_bco_central = p_cod_bco_central OR
              p_cod_bco_central IS NULL);
      END IF;
    END IF;
    --BSEVOCORE-904 Asigna el código swift correcto de GNB FUSION Ex BBVA
    IF p_cod_swift = 'BBVAPYPAAXX' THEN
      p_cod_swift := rpad(v_swi_banco, 11, 'X');
    END IF;
    --Fin BSEVOCORE-904

  EXCEPTION
    WHEN no_data_found THEN
      p_cod_swift := NULL;
    WHEN OTHERS THEN
      p_cod_swift := NULL;
  END;

  PROCEDURE lp_obt_dat_referencia(p_referencia   IN ge_movimientos.referencia%TYPE,
                                  p_fondo        OUT NUMBER,
                                  p_motivo       OUT NUMBER,
                                  p_financiacion OUT NUMBER) IS
    v_fondo        ge_movimientos.referencia%TYPE;
    v_motivo       ge_movimientos.referencia%TYPE;
    v_financiacion ge_movimientos.referencia%TYPE;
  BEGIN
    v_fondo        := pae_uti.fu_obt_valor(p_referencia, 1);
    v_motivo       := pae_uti.fu_obt_valor(p_referencia, 2);
    v_financiacion := pae_uti.fu_obt_valor(p_referencia, 3);
    IF length(v_fondo) > 2 THEN
      p_fondo := NULL;
    ELSE
      p_fondo := v_fondo;
    END IF;
    IF length(v_motivo) > 2 THEN
      p_motivo := NULL;
    ELSE
      p_motivo := v_motivo;
    END IF;
    IF length(v_financiacion) > 2 THEN
      p_financiacion := NULL;
    ELSE
      p_financiacion := v_financiacion;
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      p_fondo        := NULL;
      p_motivo       := NULL;
      p_financiacion := NULL;
  END;

  PROCEDURE lp_obt_dat_persona(p_nro_cuenta    IN ge_cta_clientes.nro_cuenta%TYPE DEFAULT NULL,
                               p_cod_persona   IN OUT ba_personas.cod_persona%TYPE,
                               p_tip_documento OUT ba_tip_documentos.abreviatura%TYPE,
                               p_nro_documento OUT ba_personas.nro_documento%TYPE) IS
  BEGIN
    IF p_nro_cuenta IS NOT NULL THEN
      BEGIN
        SELECT fue_obt_tip_doc_abreviatura(cod_tip_documento),
               nro_documento,
               a.cod_persona
        INTO p_tip_documento, p_nro_documento, p_cod_persona
        FROM ba_personas a, ge_cta_clientes g
        WHERE a.cod_persona = g.cod_persona
        AND g.nro_cuenta = p_nro_cuenta
        AND g.relacion = 'P';
      EXCEPTION
        WHEN no_data_found THEN
          p_tip_documento := NULL;
          p_nro_documento := NULL;
        WHEN OTHERS THEN
          p_tip_documento := NULL;
          p_nro_documento := NULL;
      END;
    ELSIF p_cod_persona IS NOT NULL THEN
      BEGIN
        SELECT fue_obt_tip_doc_abreviatura(cod_tip_documento),
               nro_documento
        INTO p_tip_documento, p_nro_documento
        FROM ba_personas a
        WHERE a.cod_persona = p_cod_persona;
      EXCEPTION
        WHEN no_data_found THEN
          p_tip_documento := NULL;
          p_nro_documento := NULL;
        WHEN OTHERS THEN
          p_tip_documento := NULL;
          p_nro_documento := NULL;
      END;
    END IF;
  END;

  PROCEDURE lp_obt_dat_oficina(p_cod_oficina IN ba_oficinas.cod_oficina%TYPE,
                               p_cod_ciudad  OUT ba_ciudades.cod_ciudad%TYPE,
                               p_cod_pais    OUT ba_paises.cod_pais%TYPE) IS
  BEGIN
    SELECT d.cod_pais, c.cod_ciudad
    INTO p_cod_pais, p_cod_ciudad
    FROM ba_oficinas a, ba_ciudades c, ba_paises d
    WHERE cod_oficina = p_cod_oficina
    AND a.cod_ciudad = c.cod_ciudad
    AND a.cod_pais = c.cod_pais
    AND d.cod_pais = c.cod_pais;
  EXCEPTION
    WHEN no_data_found THEN
      p_cod_ciudad := NULL;
      p_cod_pais   := NULL;
    WHEN OTHERS THEN
      p_cod_ciudad := NULL;
      p_cod_pais   := NULL;
  END;

  FUNCTION lf_obt_dat_concepto(p_concepto IN ge_movimientos.concepto%TYPE)
    RETURN VARCHAR2 IS
    v_resultado ge_movimientos.concepto%TYPE;
  BEGIN
    SELECT substr(p_concepto, instr(p_concepto, '{') + 1, instr(substr(p_concepto, instr(p_concepto, '{') + 1), '}') - 1)
    INTO v_resultado
    FROM dual;
    RETURN v_resultado;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END;

  PROCEDURE lp_obt_dat_msj_swift(p_msj_swift IN lc_transferencias.msj_swift%TYPE,
                                 p_campo_50k OUT VARCHAR2,
                                 p_campo_52a OUT VARCHAR2) IS
  BEGIN
    SELECT decode(instr(p_msj_swift, ':50K:/'), 0, NULL, TRIM(REPLACE(substr(substr(substr(p_msj_swift, instr(p_msj_swift, ':50K:/')), 1, instr(substr(p_msj_swift, instr(p_msj_swift, ':50K:/')), chr(10), 1)), instr(substr(substr(p_msj_swift, instr(p_msj_swift, ':50K:/')), 1, instr(substr(p_msj_swift, instr(p_msj_swift, ':50K:/')), chr(10), 1)), '/') + 1), chr(10), ' '))),
           decode(instr(p_msj_swift, ':52A:'), 0, NULL, TRIM(REPLACE(substr(substr(substr(p_msj_swift, instr(p_msj_swift, ':52A:')), 1, instr(substr(p_msj_swift, instr(p_msj_swift, ':52A:')), chr(10), 1)), instr(substr(substr(p_msj_swift, instr(p_msj_swift, ':52A:')), 1, instr(substr(p_msj_swift, instr(p_msj_swift, ':52A:')), chr(10), 1)), ':', 2) + 1), chr(10), ' ')))
    INTO p_campo_50k, p_campo_52a
    FROM dual;
  EXCEPTION
    WHEN no_data_found THEN
      NULL;
    WHEN OTHERS THEN
      NULL;
  END;

  FUNCTION lf_obt_per_banco(p_cod_banco IN ge_bancos.cod_banco%TYPE)
    RETURN NUMBER IS
    v_cod_persona ba_personas.cod_persona%TYPE;
  BEGIN
    SELECT cod_persona
    INTO v_cod_persona
    FROM ge_bancos
    WHERE cod_banco = p_cod_banco;
    RETURN v_cod_persona;
  EXCEPTION
    WHEN no_data_found THEN
      RETURN NULL;
    WHEN OTHERS THEN
      RETURN NULL;
  END;

  FUNCTION lf_obt_cod_banco(p_nro_cuenta IN cc_cta_bancarias.nro_cuenta%TYPE)
    RETURN NUMBER IS
    v_cod_banco ge_bancos.cod_banco%TYPE;
  BEGIN
    SELECT cod_banco
    INTO v_cod_banco
    FROM cc_cta_bancarias
    WHERE nro_cuenta = p_nro_cuenta;
    RETURN v_cod_banco;
  EXCEPTION
    WHEN no_data_found THEN
      RETURN NULL;
    WHEN OTHERS THEN
      RETURN NULL;
  END;

  FUNCTION lf_obt_cta_interdepartamental(p_cod_persona ba_personas.cod_persona%TYPE)
    RETURN NUMBER IS
    v_cod_departamento ba_departamentos.cod_departamento%TYPE;
  BEGIN
    SELECT d.cod_departamento
    INTO v_cod_departamento
    FROM ba_ciudades a, ba_direcciones b, ba_paises c, ba_departamentos d
    WHERE a.cod_ciudad = b.cod_ciudad
    AND a.cod_pais = b.cod_pais
    AND b.cod_pais = c.cod_pais
    AND b.cod_persona = p_cod_persona
    AND d.cod_departamento = a.cod_departamento
    AND b.principal = 'S';
    RETURN v_cod_departamento;
  EXCEPTION
    WHEN no_data_found THEN
      RETURN NULL;
    WHEN OTHERS THEN
      RETURN NULL;
  END;

  PROCEDURE lp_gen_tra_cuentas IS
    CURSOR c_movimientos IS
      SELECT DISTINCT g.fecha, g.hora, g.cod_usuario
      FROM ge_movimientos g
      WHERE ((g.cod_tra_padre = 309 AND g.cod_modalidad <> 45) OR
            g.cod_tra_padre = 388)
      AND g.reversado = 'N'
      AND g.estado = 'N'
      AND g.cod_transaccion IN (503, 602)
      AND (upper(g.concepto) NOT LIKE upper('%combinada%') AND
            upper(g.concepto) NOT LIKE upper('%Transf.CComb.Nro%') AND
            upper(g.concepto) NOT LIKE upper('%Transf.a la Cta%'))
      AND g.fecha = v_fec_actual
      AND g.nro_secuencia < 900
      AND nvl(pag_gen.fu_con_mon_a_moneda(g.cod_moneda, v_cod_mon_local, g.monto, NULL, v_fec_actual, NULL), 0) >
            v_mto_minimo
      AND NOT EXISTS (SELECT hora
             FROM ge_movimientos
             WHERE cod_tra_padre = 309
             AND reversado = 'N'
             AND estado = 'N'
             AND cod_transaccion IN (503, 602)
             AND cod_modalidad = 45
             AND nro_secuencia < 900
             AND fecha = g.fecha
             AND hora = g.hora
             AND g.nro_documento = nro_documento);
    CURSOR c_cuentas IS
      SELECT fecha,
             hora,
             cod_usuario,
             nro_secuencia,
             fec_valor,
             monto,
             nro_cuenta,
             cod_moneda,
             cod_modalidad,
             cod_oficina,
             cod_ofi_origen,
             cod_tra_padre,
             cod_mod_padre,
             cod_mad_padre,
             cod_transaccion,
             nro_documento,
             nro_documento2,
             nro_documento3,
             nro_documento4,
             referencia,
             cod_modulo
      FROM ge_movimientos
      WHERE fecha = v_fecha
      AND hora = v_hora
      AND cod_usuario = v_cod_usuario
      AND cod_tra_padre IN (309, 388)
      AND nro_secuencia < 900;
  BEGIN
    FOR i IN c_movimientos
    LOOP
      v_fecha                 := i.fecha;
      v_hora                  := i.hora;
      v_cod_usuario           := i.cod_usuario;
      rp_stdet.tip_movimiento := 3;
      rp_stdet.tip_operacion  := 'L';
      rp_stdet.fecha          := v_fec_actual;
      v_cod_per_ordenante     := NULL;
      v_cod_per_beneficiario  := NULL;
      FOR j IN c_cuentas
      LOOP
        IF j.cod_modalidad = 45
           AND j.cod_transaccion IN (503, 603) THEN
          GOTO siguiente;
        ELSE
          IF nvl(j.cod_transaccion, 0) = 503 THEN
            -- débito/origen
            rp_stdet.nro_operacion := j.nro_documento;
            rp_stdet.cod_oficina   := j.cod_ofi_origen;
            rp_stdet.cod_mon_iso   := j.cod_moneda;
            rp_stdet.fec_operacion := j.fecha;
            rp_stdet.cod_modulo    := j.cod_modulo;
            rp_stdet.cod_modalidad := j.cod_modalidad;
            lp_obt_dat_persona(j.nro_cuenta, v_cod_per_ordenante, rp_stdet.tip_doc_ordenante, rp_stdet.nro_doc_ordenante);
            pre_obt_pai_iso(v_cod_per_ordenante, NULL, NULL, rp_stdet.des_ciu_iso_origen, rp_stdet.cod_pai_iso_origen);
            rp_stdet.nro_cta_ordenante := nvl(j.nro_cuenta, 0);
            rp_stdet.monto             := j.monto;
            rp_stdet.val_conversion    := fug_obt_cotizacion(j.cod_moneda, j.fecha);
            lp_obt_cod_swift(NULL, v_cod_entidad, rp_stdet.cod_swi_bco_intermediario);
            rp_stdet.cod_swi_bco_beneficiario := rp_stdet.cod_swi_bco_intermediario;
            lp_obt_dat_referencia(j.referencia, rp_stdet.tip_fondo, rp_stdet.tip_motivo, rp_stdet.tip_financiacion);
            IF rp_stdet.tip_fondo IS NULL
               OR rp_stdet.tip_motivo IS NULL
               OR rp_stdet.tip_financiacion IS NULL THEN
              rp_stdet.tip_fondo := fu_obt_ori_fondo(rp_stdet.nro_doc_ordenante);
              IF v_cod_entidad = 1007 THEN
                rp_stdet.tip_motivo       := 10; --servicio recibido en el paraguay
                rp_stdet.tip_financiacion := 2; --deposito a cargo banco declarante
              ELSIF v_cod_entidad = 1028 THEN
                rp_stdet.tip_financiacion := 1; --Efectivo
              END IF;
            END IF;
            rp_stdet.tip_doc_transportadora := NULL;
            rp_stdet.nro_doc_transportadora := NULL;
            rp_stdet.autorizado             := fue_per_dat_adicional(v_cod_per_ordenante, 'TRA_AUT_ENV_DATOS');
          ELSIF nvl(j.cod_transaccion, 0) = 602 THEN
            -- destino/credito
            rp_stdet.nro_operacion := j.nro_documento;
            lp_obt_dat_persona(j.nro_cuenta, v_cod_per_beneficiario, rp_stdet.tip_doc_beneficiario, rp_stdet.nro_doc_beneficiario);
            pre_obt_pai_iso(v_cod_per_beneficiario, NULL, NULL, rp_stdet.des_ciu_iso_destino, rp_stdet.cod_pai_iso_destino);
            rp_stdet.nro_cta_beneficiario := nvl(j.nro_cuenta, 0);
          END IF;
        END IF;
      END LOOP;
      IF v_cod_per_ordenante <> v_cod_per_beneficiario
         AND (lf_obt_cta_interdepartamental(v_cod_per_ordenante) <>
         lf_obt_cta_interdepartamental(v_cod_per_beneficiario)) THEN
        v_nro_registro        := v_nro_registro + 1;
        rp_stdet.nro_registro := v_nro_registro;
        lp_ins_transferencias_det(rp_stdet);
      END IF;
      -- Siguiente registro
      <<siguiente>>
      NULL;
    END LOOP;
  END;

  PROCEDURE lp_gen_tra_internas IS
    v_cod_ciudad ba_ciudades.cod_ciudad%TYPE;
    v_cod_pais   ba_paises.cod_pais%TYPE;
    CURSOR c_cuentas IS
      SELECT v.cod_transferencia,
             v.fecha,
             v.cod_ofi_origen,
             v.cod_ofi_destino,
             v.cod_moneda,
             v.monto,
             v.cod_per_remitente,
             v.cod_per_beneficiario,
             v.nro_cuenta,
             v.tip_fondo,
             v.tip_motivo,
             v.tip_financiacion,
             v.cod_tip_doc_beneficiario,
             v.nro_doc_beneficiario,
             v.cod_modulo,
             v.cod_modalidad
      FROM sv_tra_internas v
      WHERE v.fecha = v_fec_actual
      AND nvl(pag_gen.fu_con_mon_a_moneda(v.cod_moneda, v_cod_mon_local, v.monto, NULL, v_fec_actual, NULL), 0) >
            v_mto_minimo;
  BEGIN
    FOR i IN c_cuentas
    LOOP
      rp_stdet.cod_oficina    := i.cod_ofi_origen;
      rp_stdet.cod_modulo     := i.cod_modulo;
      rp_stdet.cod_modalidad  := i.cod_modalidad;
      rp_stdet.nro_operacion  := i.cod_transferencia;
      rp_stdet.tip_movimiento := 3;
      rp_stdet.tip_operacion  := 'L';
      rp_stdet.fecha          := v_fec_actual;
      rp_stdet.cod_mon_iso    := i.cod_moneda;
      rp_stdet.fec_operacion  := i.fecha;
      lp_obt_dat_persona(NULL, i.cod_per_remitente, rp_stdet.tip_doc_ordenante, rp_stdet.nro_doc_ordenante);
      lp_obt_dat_oficina(i.cod_ofi_origen, v_cod_ciudad, v_cod_pais);
      pre_obt_pai_iso(NULL, v_cod_pais, v_cod_ciudad, rp_stdet.des_ciu_iso_origen, rp_stdet.cod_pai_iso_origen);
      rp_stdet.nro_cta_ordenante := nvl(i.nro_cuenta, 0);
      rp_stdet.monto             := i.monto;
      rp_stdet.val_conversion    := fug_obt_cotizacion(i.cod_moneda, i.fecha);
      lp_obt_cod_swift(NULL, v_cod_entidad, rp_stdet.cod_swi_bco_intermediario);
      rp_stdet.cod_swi_bco_beneficiario := rp_stdet.cod_swi_bco_intermediario;
      rp_stdet.tip_fondo                := i.tip_fondo;
      rp_stdet.tip_motivo               := i.tip_motivo;
      rp_stdet.tip_financiacion         := i.tip_financiacion;
      rp_stdet.tip_doc_transportadora   := NULL;
      rp_stdet.nro_doc_transportadora   := NULL;
      rp_stdet.autorizado               := fue_per_dat_adicional(i.cod_per_beneficiario, 'TRA_AUT_ENV_DATOS');
      IF i.cod_per_beneficiario IS NULL THEN
        v_cod_per_beneficiario        := fue_obt_cod_persona_doc(i.cod_tip_doc_beneficiario, i.nro_doc_beneficiario);
        rp_stdet.nro_doc_beneficiario := i.nro_doc_beneficiario;
        IF i.cod_tip_doc_beneficiario IS NOT NULL THEN
          rp_stdet.tip_doc_beneficiario := fue_obt_tip_doc_abreviatura(i.cod_tip_doc_beneficiario);
        END IF;
      ELSE
        v_cod_per_beneficiario := i.cod_per_beneficiario;
      END IF;
      lp_obt_dat_persona(NULL, v_cod_per_beneficiario, rp_stdet.tip_doc_beneficiario, rp_stdet.nro_doc_beneficiario);
      lp_obt_dat_oficina(i.cod_ofi_destino, v_cod_ciudad, v_cod_pais);
      pre_obt_pai_iso(NULL, v_cod_pais, v_cod_ciudad, rp_stdet.des_ciu_iso_destino, rp_stdet.cod_pai_iso_destino);
      rp_stdet.nro_cta_beneficiario := 0;
      IF i.cod_per_remitente <> v_cod_per_beneficiario THEN
        v_nro_registro        := v_nro_registro + 1;
        rp_stdet.nro_registro := v_nro_registro;
        lp_ins_transferencias_det(rp_stdet);
      END IF;
    END LOOP;
  END;

  PROCEDURE lp_tra_emitidas IS
    v_nro_doc_beneficiario ba_personas.nro_documento%TYPE;
    v_tra_anterior         NUMBER := 0;
    CURSOR c_movimientos IS
      SELECT DISTINCT g.fecha, g.hora, g.cod_usuario, g.cod_tip_ope_cambio
      FROM ge_movimientos g, lc_transferencias l
      WHERE g.nro_documento = l.nro_operacion
      AND g.cod_mod_padre = 7
      AND g.cod_mad_padre IN (72, 73, 74)
      AND g.cod_tra_padre IN (264, 300, 768, 848)
      AND g.reversado = 'N'
      AND g.estado = 'N'
      AND l.estado = 'E'
      AND g.nro_secuencia < 900
      AND l.fec_cam_estado = v_fec_actual
      AND trunc(l.fec_insercion) = l.fec_envio --DYDMR-9385 Incidencia SAU - ITGF - Informe Sistema SOFIA
      AND to_number(g.cod_tip_ope_cambio) IN
            (SELECT MAX(to_number(m.cod_tip_ope_cambio))
             FROM ge_movimientos m
             WHERE m.cod_mod_padre = 7
             AND m.cod_mad_padre IN (72, 73, 74)
             AND m.cod_tra_padre IN (264, 300, 768, 848)
             AND m.reversado = 'N'
             AND m.estado = 'N'
             AND m.nro_secuencia < 900
             AND g.nro_documento = m.nro_documento);
    CURSOR c_cuentas IS
      SELECT g.fecha,
             g.nro_cuenta,
             g.cod_ofi_origen,
             g.cod_transaccion,
             g.nro_documento,
             l.nro_operacion,
             l.fec_operacion,
             l.cod_moneda,
             l.monto,
             l.cod_swi_banco,
             l.cod_per_solicitante,
             l.cod_pai_solicitante,
             l.cod_ciu_solicitante,
             l.nro_doc_beneficiario,
             l.nro_referencia,
             l.cod_per_beneficiario,
             l.cod_pai_beneficiario,
             l.cod_ciu_beneficiario,
             l.nro_cta_referencia,
             l.tip_fondo,
             l.tip_motivo,
             l.tip_financiacion,
             l.cod_banco,
             l.cod_bco_corresponsal,
             g.cod_modulo,
             g.cod_modalidad,
             l.cod_aba_banco,
             l.autorizado
      FROM ge_movimientos g, lc_transferencias l
      WHERE l.nro_operacion = g.nro_documento
      AND g.fecha = v_fecha
      AND g.hora = v_hora
      AND g.cod_usuario = v_cod_usuario
      AND g.nro_secuencia < 900
      AND g.cod_transaccion = 760;
    --DYDMR-8615 Incidencia SAU - ITGF - Incidente en Informe SOFIA
    PROCEDURE lp_tra_emitidas_ant IS
      v_nro_doc_beneficiario ba_personas.nro_documento%TYPE;
      CURSOR c_movimientos IS
        SELECT DISTINCT g.fecha,
                        g.hora,
                        g.cod_usuario,
                        g.cod_tip_ope_cambio
        FROM lc_movimientos_his g, lc_transferencias l
        WHERE g.nro_documento = l.nro_operacion
        AND g.cod_mod_padre = 7
        AND g.cod_mad_padre IN (72, 73, 74)
        AND g.cod_tra_padre IN (264, 300, 768, 848)
        AND g.reversado = 'N'
        AND g.estado = 'N'
        AND l.estado = 'E'
        AND g.nro_secuencia < 900
        AND l.fec_cam_estado = v_fec_actual
        AND g.fecha = trunc(l.fec_insercion)
        AND trunc(l.fec_insercion) <> l.fec_envio --DYDMR-9385 Incidencia SAU - ITGF - Informe Sistema SOFIA
        AND to_number(g.cod_tip_ope_cambio) IN
              (SELECT MAX(to_number(m.cod_tip_ope_cambio))
               FROM lc_movimientos_his m
               WHERE m.cod_mod_padre = 7
               AND m.cod_mad_padre IN (72, 73, 74)
               AND m.cod_tra_padre IN (264, 300, 768, 848)
               AND m.reversado = 'N'
               AND m.estado = 'N'
               AND m.nro_secuencia < 900
               AND m.fecha = g.fecha
               AND m.hora = g.hora
               AND m.cod_usuario = g.cod_usuario
               AND m.nro_documento = g.nro_documento)
        AND NOT EXISTS (SELECT 1
               FROM sb_transferencias_det t
               WHERE t.fec_operacion = l.fec_envio
               AND t.nro_operacion = l.nro_operacion);

      CURSOR c_cuentas IS
        SELECT l.fec_operacion fecha,
               g.nro_cuenta,
               g.cod_ofi_origen,
               g.cod_transaccion,
               g.nro_documento,
               l.nro_operacion,
               l.fec_operacion,
               l.cod_moneda,
               l.monto,
               l.cod_swi_banco,
               l.cod_per_solicitante,
               l.cod_pai_solicitante,
               l.cod_ciu_solicitante,
               l.nro_doc_beneficiario,
               l.nro_referencia,
               l.cod_per_beneficiario,
               l.cod_pai_beneficiario,
               l.cod_ciu_beneficiario,
               l.nro_cta_referencia,
               l.tip_fondo,
               l.tip_motivo,
               l.tip_financiacion,
               l.cod_banco,
               l.cod_bco_corresponsal,
               g.cod_modulo,
               g.cod_modalidad,
               l.cod_aba_banco,
               l.autorizado
        FROM lc_movimientos_his g, lc_transferencias l
        WHERE l.nro_operacion = g.nro_documento
        AND g.fecha = v_fecha
        AND g.hora = v_hora
        AND g.cod_usuario = v_cod_usuario
        AND g.fecha = trunc(l.fec_insercion)
        AND g.nro_secuencia < 900
        AND g.cod_transaccion = 760;
    BEGIN
      FOR i IN c_movimientos
      LOOP
        v_fecha                 := i.fecha;
        v_hora                  := i.hora;
        v_cod_usuario           := i.cod_usuario;
        rp_stdet.tip_movimiento := 2;
        rp_stdet.fecha          := v_fec_actual;
        BEGIN
          SELECT nro_cuenta
          INTO rp_stdet.nro_cta_ordenante
          FROM lc_movimientos_his
          WHERE fecha = v_fecha
          AND hora = v_hora
          AND cod_usuario = v_cod_usuario
          AND cod_mad_padre IN (72, 73, 74)
          AND cod_transaccion = 503;
        EXCEPTION
          WHEN no_data_found THEN
            rp_stdet.nro_cta_ordenante := 0;
          WHEN OTHERS THEN
            rp_stdet.nro_cta_ordenante := 0;
        END;
        IF i.cod_tip_ope_cambio = 140 THEN
          rp_stdet.tip_operacion := 'I';
        ELSE
          rp_stdet.tip_operacion := 'E';
        END IF;
        FOR j IN c_cuentas
        LOOP
          rp_stdet.cod_modulo    := j.cod_modulo;
          rp_stdet.cod_modalidad := j.cod_modalidad;
          rp_stdet.cod_oficina   := j.cod_ofi_origen;
          rp_stdet.nro_operacion := j.nro_operacion;
          rp_stdet.cod_mon_iso   := j.cod_moneda;
          rp_stdet.fec_operacion := j.fec_operacion;
          lp_obt_dat_persona(NULL, j.cod_per_solicitante, rp_stdet.tip_doc_ordenante, rp_stdet.nro_doc_ordenante);
          IF j.cod_pai_solicitante IS NULL THEN
            pre_obt_pai_iso(j.cod_per_solicitante, NULL, NULL, rp_stdet.des_ciu_iso_origen, rp_stdet.cod_pai_iso_origen);
          ELSE
            pre_obt_pai_iso(NULL, j.cod_pai_solicitante, j.cod_ciu_solicitante, rp_stdet.des_ciu_iso_origen, rp_stdet.cod_pai_iso_origen);
          END IF;
          rp_stdet.monto          := j.monto;
          rp_stdet.val_conversion := fug_obt_cotizacion(j.cod_moneda, j.fec_operacion);
          lp_obt_cod_swift(j.cod_bco_corresponsal, NULL, rp_stdet.cod_swi_bco_intermediario);
          IF rp_stdet.cod_swi_bco_intermediario IS NULL THEN
            lp_obt_cod_swift(NULL, v_cod_entidad, rp_stdet.cod_swi_bco_intermediario);
          END IF;
          rp_stdet.cod_swi_bco_beneficiario := substr(j.cod_swi_banco, 1, 11);
          IF rp_stdet.cod_swi_bco_beneficiario IS NULL THEN
            lp_obt_cod_swift(j.cod_banco, NULL, rp_stdet.cod_swi_bco_beneficiario);
            IF rp_stdet.cod_swi_bco_beneficiario IS NULL THEN
              rp_stdet.cod_swi_bco_beneficiario := j.cod_aba_banco;
            END IF;
          ELSE
            rp_stdet.cod_swi_bco_beneficiario := rpad(rp_stdet.cod_swi_bco_beneficiario, 11, 'X');
          END IF;
          rp_stdet.nro_cta_beneficiario   := nvl(j.nro_cta_referencia, 0);
          rp_stdet.tip_fondo              := j.tip_fondo;
          rp_stdet.tip_motivo             := j.tip_motivo;
          rp_stdet.tip_financiacion       := j.tip_financiacion;
          rp_stdet.tip_doc_transportadora := NULL;
          rp_stdet.nro_doc_transportadora := NULL;
          rp_stdet.autorizado             := j.autorizado;
          lp_obt_dat_persona(NULL, j.cod_per_beneficiario, rp_stdet.tip_doc_beneficiario, v_nro_doc_beneficiario);
          IF j.cod_per_beneficiario IS NOT NULL THEN
            lp_obt_dat_persona(NULL, j.cod_per_beneficiario, rp_stdet.tip_doc_beneficiario, rp_stdet.nro_doc_beneficiario);
          ELSE
            rp_stdet.nro_doc_beneficiario := j.nro_doc_beneficiario;
            rp_stdet.tip_doc_beneficiario := NULL;
          END IF;
          pre_obt_pai_iso(NULL, j.cod_pai_beneficiario, j.cod_ciu_beneficiario, rp_stdet.des_ciu_iso_destino, rp_stdet.cod_pai_iso_destino);
        END LOOP;
        v_nro_registro        := v_nro_registro + 1;
        rp_stdet.nro_registro := v_nro_registro;
        lp_ins_transferencias_det(rp_stdet);
      END LOOP;

    END lp_tra_emitidas_ant;

  BEGIN
    FOR i IN c_movimientos
    LOOP
      v_fecha                 := i.fecha;
      v_hora                  := i.hora;
      v_cod_usuario           := i.cod_usuario;
      rp_stdet.tip_movimiento := 2;
      rp_stdet.fecha          := v_fec_actual;
      BEGIN
        SELECT nro_cuenta
        INTO rp_stdet.nro_cta_ordenante
        FROM ge_movimientos
        WHERE fecha = v_fecha
        AND hora = v_hora
        AND cod_usuario = v_cod_usuario
        AND cod_mad_padre IN (72, 73, 74)
        AND cod_transaccion = 503;
      EXCEPTION
        WHEN no_data_found THEN
          rp_stdet.nro_cta_ordenante := 0;
        WHEN OTHERS THEN
          rp_stdet.nro_cta_ordenante := 0;
      END;
      IF i.cod_tip_ope_cambio = 140 THEN
        rp_stdet.tip_operacion := 'I';
      ELSE
        rp_stdet.tip_operacion := 'E';
      END IF;
      FOR j IN c_cuentas
      LOOP
        rp_stdet.cod_modulo    := j.cod_modulo;
        rp_stdet.cod_modalidad := j.cod_modalidad;
        rp_stdet.cod_oficina   := j.cod_ofi_origen;
        rp_stdet.nro_operacion := j.nro_operacion;
        rp_stdet.cod_mon_iso   := j.cod_moneda;
        rp_stdet.fec_operacion := j.fec_operacion;
        lp_obt_dat_persona(NULL, j.cod_per_solicitante, rp_stdet.tip_doc_ordenante, rp_stdet.nro_doc_ordenante);
        IF j.cod_pai_solicitante IS NULL THEN
          pre_obt_pai_iso(j.cod_per_solicitante, NULL, NULL, rp_stdet.des_ciu_iso_origen, rp_stdet.cod_pai_iso_origen);
        ELSE
          pre_obt_pai_iso(NULL, j.cod_pai_solicitante, j.cod_ciu_solicitante, rp_stdet.des_ciu_iso_origen, rp_stdet.cod_pai_iso_origen);
        END IF;
        rp_stdet.monto          := j.monto;
        rp_stdet.val_conversion := fug_obt_cotizacion(j.cod_moneda, j.fec_operacion);
        lp_obt_cod_swift(j.cod_bco_corresponsal, NULL, rp_stdet.cod_swi_bco_intermediario);
        IF rp_stdet.cod_swi_bco_intermediario IS NULL THEN
          lp_obt_cod_swift(NULL, v_cod_entidad, rp_stdet.cod_swi_bco_intermediario);
        END IF;
        rp_stdet.cod_swi_bco_beneficiario := substr(j.cod_swi_banco, 1, 11);
        IF rp_stdet.cod_swi_bco_beneficiario IS NULL THEN
          lp_obt_cod_swift(j.cod_banco, NULL, rp_stdet.cod_swi_bco_beneficiario);
          IF rp_stdet.cod_swi_bco_beneficiario IS NULL THEN
            rp_stdet.cod_swi_bco_beneficiario := j.cod_aba_banco;
          END IF;
        ELSE
          rp_stdet.cod_swi_bco_beneficiario := rpad(rp_stdet.cod_swi_bco_beneficiario, 11, 'X');
        END IF;
        rp_stdet.nro_cta_beneficiario   := nvl(j.nro_cta_referencia, 0);
        rp_stdet.tip_fondo              := j.tip_fondo;
        rp_stdet.tip_motivo             := j.tip_motivo;
        rp_stdet.tip_financiacion       := j.tip_financiacion;
        rp_stdet.tip_doc_transportadora := NULL;
        rp_stdet.nro_doc_transportadora := NULL;
        rp_stdet.autorizado             := j.autorizado;
        lp_obt_dat_persona(NULL, j.cod_per_beneficiario, rp_stdet.tip_doc_beneficiario, v_nro_doc_beneficiario);
        IF j.cod_per_beneficiario IS NOT NULL THEN
          lp_obt_dat_persona(NULL, j.cod_per_beneficiario, rp_stdet.tip_doc_beneficiario, rp_stdet.nro_doc_beneficiario);
        ELSE
          rp_stdet.nro_doc_beneficiario := j.nro_doc_beneficiario;
          rp_stdet.tip_doc_beneficiario := NULL;
        END IF;
        pre_obt_pai_iso(NULL, j.cod_pai_beneficiario, j.cod_ciu_beneficiario, rp_stdet.des_ciu_iso_destino, rp_stdet.cod_pai_iso_destino);
      END LOOP;
      v_nro_registro        := v_nro_registro + 1;
      rp_stdet.nro_registro := v_nro_registro;
      lp_ins_transferencias_det(rp_stdet);
    END LOOP;
    BEGIN
      SELECT nvl(COUNT(*), 0)
      INTO v_tra_anterior
      FROM lc_transferencias r
      WHERE r.fec_envio = v_fec_actual
      AND trunc(r.fec_insercion) <> trunc(r.fec_envio)
      AND NOT EXISTS (SELECT 1
             FROM sb_transferencias_det t
             WHERE t.nro_operacion = r.nro_operacion
             AND t.fec_operacion = r.fec_operacion);

    EXCEPTION
      WHEN no_data_found THEN
        v_tra_anterior := 0;
    END;
    --DYDMR-8615 Incidencia SAU - ITGF - Incidente en Informe SOFIA
    ---Si existen transferencias que fueron enviados posterior a la fecha de carga
    IF v_tra_anterior <> 0 THEN
      ---transferencias
      lp_tra_emitidas_ant;
    END IF;

  END;

  PROCEDURE lp_tra_emi_corresponsales IS
    v_cod_banco ge_bancos.cod_banco%TYPE;
    CURSOR c_movimientos IS
      SELECT DISTINCT g.fecha, g.hora, g.cod_usuario
      FROM ge_movimientos g
      WHERE g.cod_tra_padre IN (309, 396)
      AND g.cod_modalidad = 45
      AND g.reversado = 'N'
      AND g.estado = 'N'
      AND g.cod_transaccion IN (602, 191)
      AND monto > 0
      AND g.fecha = v_fec_actual
      AND g.nro_secuencia < 900
      AND NOT EXISTS (SELECT hora
             FROM ge_movimientos
             WHERE reversado = 'N'
             AND estado = 'N'
             AND cod_modalidad = 45
             AND cod_transaccion = 503
             AND nro_secuencia < 900
             AND fecha = g.fecha
             AND hora = g.hora
             AND g.nro_documento = nro_documento);
    CURSOR c_cuentas IS
      SELECT g.fecha,
             g.nro_cuenta,
             g.cod_ofi_origen,
             g.cod_transaccion,
             g.nro_documento,
             g.monto,
             g.cod_moneda,
             g.cod_tra_padre,
             g.cod_mod_padre,
             g.cod_mad_padre,
             g.referencia,
             g.cod_modulo,
             g.cod_modalidad
      FROM ge_movimientos g
      WHERE g.fecha = v_fecha
      AND g.hora = v_hora
      AND g.cod_usuario = v_cod_usuario
      AND g.cod_tra_padre IN (309, 396)
      AND g.nro_secuencia < 900
      AND ((g.cod_modalidad = 45 AND g.cod_transaccion IN (602, 191)) OR
            g.cod_modalidad <> 45 AND g.cod_transaccion = 503);
  BEGIN
    FOR i IN c_movimientos
    LOOP
      v_fecha                 := i.fecha;
      v_hora                  := i.hora;
      v_cod_usuario           := i.cod_usuario;
      rp_stdet.tip_movimiento := 4;
      rp_stdet.tip_operacion  := 'E';
      rp_stdet.fecha          := v_fec_actual;
      FOR j IN c_cuentas
      LOOP
        IF nvl(j.cod_transaccion, 0) = 503 THEN
          -- débito/origen
          rp_stdet.cod_modulo    := j.cod_modulo;
          rp_stdet.cod_modalidad := j.cod_modalidad;
          rp_stdet.cod_oficina   := j.cod_ofi_origen;
          rp_stdet.nro_operacion := j.nro_documento;
          rp_stdet.fec_operacion := j.fecha;
          lp_obt_dat_persona(j.nro_cuenta, v_cod_persona, rp_stdet.tip_doc_ordenante, rp_stdet.nro_doc_ordenante);
          pre_obt_pai_iso(v_cod_persona, NULL, NULL, rp_stdet.des_ciu_iso_origen, rp_stdet.cod_pai_iso_origen);
          rp_stdet.nro_cta_ordenante := nvl(j.nro_cuenta, 0);
          rp_stdet.val_conversion    := fug_obt_cotizacion(j.cod_moneda, j.fecha);
          lp_obt_cod_swift(NULL, v_cod_entidad, rp_stdet.cod_swi_bco_intermediario);
          rp_stdet.tip_doc_transportadora := NULL;
          rp_stdet.nro_doc_transportadora := NULL;
          rp_stdet.autorizado             := fue_per_dat_adicional(v_cod_persona, 'TRA_AUT_ENV_DATOS');
        ELSIF nvl(j.cod_transaccion, 0) IN (602, 191) THEN
          -- destino/credito
          rp_stdet.cod_mon_iso := j.cod_moneda;
          rp_stdet.monto       := j.monto;
          lp_obt_dat_persona(j.nro_cuenta, v_cod_persona, rp_stdet.tip_doc_beneficiario, rp_stdet.nro_doc_beneficiario);
          IF j.cod_transaccion = 602 THEN
            lp_obt_dat_referencia(j.referencia, rp_stdet.tip_fondo, rp_stdet.tip_motivo, rp_stdet.tip_financiacion);
          ELSE
            BEGIN
              SELECT tip_fondo, tip_motivo, tip_financiacion
              INTO rp_stdet.tip_fondo,
                   rp_stdet.tip_motivo,
                   rp_stdet.tip_financiacion
              FROM lc_transferencias
              WHERE nro_operacion = j.nro_documento;
            EXCEPTION
              WHEN no_data_found THEN
                rp_stdet.tip_fondo        := NULL;
                rp_stdet.tip_motivo       := NULL;
                rp_stdet.tip_financiacion := NULL;
              WHEN OTHERS THEN
                rp_stdet.tip_fondo        := NULL;
                rp_stdet.tip_motivo       := NULL;
                rp_stdet.tip_financiacion := NULL;
            END;
          END IF;
          pre_obt_pai_iso(v_cod_persona, NULL, NULL, rp_stdet.des_ciu_iso_destino, rp_stdet.cod_pai_iso_destino);
          v_cod_banco := lf_obt_cod_banco(j.nro_cuenta);
          lp_obt_cod_swift(v_cod_banco, NULL, rp_stdet.cod_swi_bco_beneficiario);
          rp_stdet.nro_cta_beneficiario := nvl(j.nro_cuenta, 0);
        END IF;
      END LOOP;
      v_nro_registro        := v_nro_registro + 1;
      rp_stdet.nro_registro := v_nro_registro;
      lp_ins_transferencias_det(rp_stdet);
    END LOOP;
  END;

  PROCEDURE lp_tra_rec_corresponsales IS
    v_cod_banco ge_bancos.cod_banco%TYPE;
    CURSOR c_movimientos IS
      SELECT DISTINCT g.fecha, g.hora, g.cod_usuario
      FROM ge_movimientos g
      WHERE g.cod_tra_padre = 309 -- 309 trans
      AND g.cod_modalidad = 45
      AND g.reversado = 'N'
      AND g.estado = 'N'
      AND g.cod_transaccion = 503
      AND monto > 0
      AND g.fecha = v_fec_actual
      AND g.nro_secuencia < 900
      AND NOT EXISTS (SELECT hora
             FROM ge_movimientos
             WHERE reversado = 'N'
             AND estado = 'N'
             AND cod_modalidad = 45
             AND cod_transaccion = 602
             AND nro_secuencia < 900
             AND fecha = g.fecha
             AND hora = g.hora
             AND g.nro_documento = nro_documento);
    CURSOR c_cuentas IS
      SELECT g.fecha,
             g.nro_cuenta,
             g.cod_ofi_origen,
             g.cod_transaccion,
             g.nro_documento,
             g.monto,
             g.cod_moneda,
             g.cod_tra_padre,
             g.cod_mod_padre,
             g.cod_mad_padre,
             g.referencia,
             g.cod_modulo,
             g.cod_modalidad
      FROM ge_movimientos g
      WHERE g.fecha = v_fecha
      AND g.hora = v_hora
      AND g.cod_usuario = v_cod_usuario
      AND g.nro_secuencia < 900
      AND (g.cod_modalidad = 45 AND g.cod_transaccion = 503 OR
            g.cod_modalidad <> 45 AND g.cod_transaccion = 602);
  BEGIN
    FOR i IN c_movimientos
    LOOP
      v_fecha                 := i.fecha;
      v_hora                  := i.hora;
      v_cod_usuario           := i.cod_usuario;
      rp_stdet.tip_movimiento := 4;
      rp_stdet.tip_operacion  := 'R';
      rp_stdet.fecha          := v_fec_actual;
      FOR j IN c_cuentas
      LOOP
        IF nvl(j.cod_transaccion, 0) = 503 THEN
          -- débito/origen
          rp_stdet.cod_modulo    := j.cod_modulo;
          rp_stdet.cod_modalidad := j.cod_modalidad;
          rp_stdet.cod_oficina   := j.cod_ofi_origen;
          rp_stdet.cod_mon_iso   := j.cod_moneda;
          rp_stdet.nro_operacion := j.nro_documento;
          rp_stdet.fec_operacion := j.fecha;
          lp_obt_dat_persona(j.nro_cuenta, v_cod_persona, rp_stdet.tip_doc_ordenante, rp_stdet.nro_doc_ordenante);
          pre_obt_pai_iso(v_cod_per_entidad, NULL, NULL, rp_stdet.des_ciu_iso_origen, rp_stdet.cod_pai_iso_origen);
          rp_stdet.nro_cta_ordenante := nvl(j.nro_cuenta, 0);
          rp_stdet.monto             := j.monto;
          rp_stdet.val_conversion    := fug_obt_cotizacion(j.cod_moneda, j.fecha);
          v_cod_banco                := lf_obt_cod_banco(j.nro_cuenta);
          lp_obt_cod_swift(v_cod_banco, NULL, rp_stdet.cod_swi_bco_intermediario);
          lp_obt_dat_referencia(j.referencia, rp_stdet.tip_fondo, rp_stdet.tip_motivo, rp_stdet.tip_financiacion);
          rp_stdet.tip_doc_transportadora := NULL;
          rp_stdet.nro_doc_transportadora := NULL;
        ELSIF nvl(j.cod_transaccion, 0) = 602 THEN
          -- destino/credito
          lp_obt_dat_persona(j.nro_cuenta, v_cod_persona, rp_stdet.tip_doc_beneficiario, rp_stdet.nro_doc_beneficiario);
          pre_obt_pai_iso(v_cod_persona, NULL, NULL, rp_stdet.des_ciu_iso_destino, rp_stdet.cod_pai_iso_destino);
          lp_obt_cod_swift(NULL, v_cod_entidad, rp_stdet.cod_swi_bco_beneficiario);
          rp_stdet.nro_cta_beneficiario := nvl(j.nro_cuenta, 0);
        END IF;
      END LOOP;
      v_nro_registro        := v_nro_registro + 1;
      rp_stdet.nro_registro := v_nro_registro;
      lp_ins_transferencias_det(rp_stdet);
    END LOOP;
  END;

  PROCEDURE lp_gen_tra_recibidas IS
    v_nro_doc_beneficiario ba_personas.nro_documento%TYPE;
    CURSOR c_transferencias IS
      SELECT DISTINCT l.nro_referencia,
                      l.cod_oficina,
                      l.fec_operacion,
                      l.nro_operacion,
                      l.cod_moneda,
                      l.monto,
                      l.nro_cta_referencia,
                      l.cod_banco,
                      l.cod_pai_banco,
                      l.cod_ciu_banco,
                      l.cod_swi_banco,
                      l.cod_bco_corresponsal,
                      l.cod_per_solicitante,
                      l.cod_pai_solicitante,
                      l.cod_ciu_solicitante,
                      l.cod_per_beneficiario,
                      l.cod_pai_beneficiario,
                      l.cod_ciu_beneficiario,
                      l.nro_ref_externa,
                      l.nro_doc_beneficiario,
                      l.tip_fondo,
                      l.tip_motivo,
                      l.tip_financiacion,
                      l.msj_swift,
                      g.cod_modulo,
                      g.cod_modalidad
      FROM lc_transferencias l, ge_movimientos g
      WHERE l.nro_operacion = g.nro_documento
      AND l.fec_cam_estado = v_fec_actual
      AND l.cod_modalidad = 75
      AND l.estado = 'OK'
      AND g.cod_transaccion = 760;
  BEGIN
    FOR i IN c_transferencias
    LOOP
      rp_stdet.tip_movimiento := 1;
      rp_stdet.tip_operacion  := 'R';
      rp_stdet.fecha          := v_fec_actual;
      rp_stdet.cod_modulo     := i.cod_modulo;
      rp_stdet.cod_modalidad  := i.cod_modalidad;
      rp_stdet.cod_oficina    := i.cod_oficina;
      rp_stdet.nro_operacion  := i.nro_operacion;
      rp_stdet.cod_mon_iso    := i.cod_moneda;
      rp_stdet.fec_operacion  := i.fec_operacion;
      lp_obt_dat_persona(NULL, i.cod_per_solicitante, rp_stdet.tip_doc_ordenante, rp_stdet.nro_doc_ordenante);
      lp_obt_dat_msj_swift(i.msj_swift, rp_stdet.nro_cta_ordenante, rp_stdet.cod_swi_bco_intermediario);
      rp_stdet.cod_swi_bco_intermediario := rpad(rp_stdet.cod_swi_bco_intermediario, 11, 'X');
      pre_obt_pai_iso(NULL, i.cod_pai_solicitante, i.cod_ciu_solicitante, rp_stdet.des_ciu_iso_origen, rp_stdet.cod_pai_iso_origen);
      rp_stdet.monto          := i.monto;
      rp_stdet.val_conversion := fug_obt_cotizacion(i.cod_moneda, i.fec_operacion);
      --rp_stdet.cod_swi_bco_beneficiario  := rpad(i.cod_swi_banco, 11, 'X');
      --BSEVOCORE-904 Para transferencias recibidas, el beneficiario debe ser el banco.
      rp_stdet.cod_swi_bco_beneficiario := rpad(v_swi_banco, 11, 'X');
      rp_stdet.nro_cta_beneficiario     := nvl(i.nro_cta_referencia, 0);
      rp_stdet.tip_fondo                := i.tip_fondo;
      rp_stdet.tip_motivo               := i.tip_motivo;
      rp_stdet.tip_financiacion         := i.tip_financiacion;
      rp_stdet.tip_doc_transportadora   := NULL;
      rp_stdet.nro_doc_transportadora   := NULL;
      lp_obt_dat_persona(NULL, i.cod_per_beneficiario, rp_stdet.tip_doc_beneficiario, v_nro_doc_beneficiario);
      rp_stdet.nro_doc_beneficiario := i.nro_doc_beneficiario;
      rp_stdet.autorizado           := fue_per_dat_adicional(i.cod_per_beneficiario, 'TRA_AUT_ENV_DATOS');
      pre_obt_pai_iso(NULL, i.cod_pai_beneficiario, i.cod_ciu_beneficiario, rp_stdet.des_ciu_iso_destino, rp_stdet.cod_pai_iso_destino);
      v_nro_registro        := v_nro_registro + 1;
      rp_stdet.nro_registro := v_nro_registro;
      lp_ins_transferencias_det(rp_stdet);
    END LOOP;
  END;

  PROCEDURE lp_gen_tra_rec_sipap IS
    v_cod_per_ordenante ba_personas.cod_persona%TYPE;
    v_tip_doc_ordenante VARCHAR2(10);
    v_ref_aux           VARCHAR2(100); 
    CURSOR c_transferencias IS
      SELECT nro_referencia,
             cod_oficina,
             cod_moneda,
             monto,
             fec_valor,
             cod_per_solicitante,
             cod_tip_doc_solicitante,
             nro_doc_solicitante,
             nro_cta_solicitante,
             cod_swi_pte_solicitante,
             nro_cta_pte_solicitante,
             cod_per_beneficiario,
             cod_tip_doc_beneficiario,
             nro_doc_beneficiario,
             nro_cta_beneficiario,
             nro_cta_pte_beneficiario,
             cod_swi_pte_beneficiario,
             nro_ref_externa,
             cod_msj_swift,
             nro_operacion,
             cod_modulo,
             cod_modalidad
      FROM ge_snp_transferencias
      WHERE fec_valor = v_fec_actual
      AND nro_ref_externa IS NOT NULL
      AND fec_recepcion IS NOT NULL
      AND situacion = 'L'
      AND estado = 'A'
      AND nvl(pag_gen.fu_con_mon_a_moneda(cod_moneda, v_cod_mon_local, monto, NULL, v_fec_actual, NULL), 0) >
            v_mto_minimo
      AND (cod_msj_swift = 202 AND cod_tip_operacion NOT IN ('003', '002') OR
            cod_msj_swift <> 202);
  BEGIN
    FOR i IN c_transferencias
    LOOP
      rp_stdet.fecha          := v_fec_actual;
      rp_stdet.tip_movimiento := 3;
      rp_stdet.tip_operacion  := 'L';
      rp_stdet.cod_oficina    := i.cod_oficina;
      rp_stdet.nro_operacion  := i.nro_referencia;
      rp_stdet.cod_mon_iso    := i.cod_moneda;
      rp_stdet.fec_operacion  := i.fec_valor;
      rp_stdet.cod_modulo     := i.cod_modulo;
      rp_stdet.cod_modalidad  := i.cod_modalidad;
      rp_stdet.monto          := i.monto;
      rp_stdet.val_conversion := fug_obt_cotizacion(i.cod_moneda, i.fec_valor);
      --solicitante
      IF i.cod_per_solicitante IS NULL THEN
        v_cod_per_ordenante := fue_obt_cod_persona_doc(i.cod_tip_doc_solicitante, i.nro_doc_solicitante);
        IF v_cod_per_ordenante IS NULL THEN
          BEGIN
            SELECT cod_persona
            INTO v_cod_per_ordenante
            FROM gv_snp_participantes
            WHERE cod_swift = i.cod_swi_pte_solicitante;
          EXCEPTION
            WHEN OTHERS THEN
              v_cod_per_ordenante := NULL;
          END;
        END IF;
      ELSE
        v_cod_per_ordenante := i.cod_per_solicitante;
      END IF;
      IF i.nro_doc_solicitante IS NOT NULL
         AND i.cod_tip_doc_solicitante IS NOT NULL THEN
         v_tip_doc_ordenante := fue_obt_tip_doc_abreviatura(i.cod_tip_doc_solicitante);

           IF v_tip_doc_ordenante = 'OJUD' THEN
              IF INSTR(i.nro_doc_solicitante, '-') > 0 THEN
                 rp_stdet.tip_doc_ordenante := 'RUC';
              ELSE
                 rp_stdet.tip_doc_ordenante := 'CI';
              END IF;
           ELSE
              -- Busca equivalencia definida --
              v_ref_aux := fue_obt_val_max_refcodes('SIB_TIP_DOC_BCP', v_tip_doc_ordenante);

              -- si no encontro por defecto CRC --
              IF v_ref_aux = 'Referencia no registrada en el Sistema' OR v_ref_aux IS NULL THEN
                rp_stdet.tip_doc_ordenante := 'CRC';
              ELSE
                rp_stdet.tip_doc_ordenante := v_ref_aux;
              END IF;
           END IF;
           rp_stdet.nro_doc_ordenante := i.nro_doc_solicitante; 
      ELSE
        lp_obt_dat_persona(NULL, v_cod_per_ordenante, rp_stdet.tip_doc_ordenante, rp_stdet.nro_doc_ordenante);
      END IF;
      rp_stdet.nro_cta_ordenante := i.nro_cta_solicitante;
      IF rp_stdet.nro_cta_ordenante IS NULL THEN
        rp_stdet.nro_cta_ordenante := nvl(i.nro_cta_pte_solicitante, 0);
      END IF;
      pre_obt_pai_iso(v_cod_per_ordenante, NULL, NULL, rp_stdet.des_ciu_iso_origen, rp_stdet.cod_pai_iso_origen);
      --BSEVOCORE-904 El campo COD_PAI_ISO_ORIGEN no debe ser nulo, y las Tranf. via SIPAP todas deben ser PY
      IF rp_stdet.cod_pai_iso_origen IS NULL THEN
        rp_stdet.cod_pai_iso_origen := 'PY';
      END IF;
      --Fin BSEVOCORE-904

      --beneficiario
      IF i.cod_per_beneficiario IS NULL THEN
        v_cod_per_beneficiario := fue_obt_cod_persona_doc(i.cod_tip_doc_beneficiario, i.nro_doc_beneficiario);
        IF v_cod_per_beneficiario IS NULL THEN
          BEGIN
            SELECT cod_persona
            INTO v_cod_per_beneficiario
            FROM gv_snp_participantes
            WHERE cod_swift = i.cod_swi_pte_beneficiario;
          EXCEPTION
            WHEN OTHERS THEN
              v_cod_per_beneficiario := NULL;
          END;
        END IF;
      ELSE
        v_cod_per_beneficiario := i.cod_per_beneficiario;
      END IF;
      rp_stdet.nro_cta_beneficiario := substr(i.nro_cta_beneficiario, 1, 30); --DYDMR-20458 se agrega substr por error en cierre 11/02/22 C.O
      IF rp_stdet.nro_cta_beneficiario IS NULL THEN
        rp_stdet.nro_cta_beneficiario := nvl(i.nro_cta_pte_beneficiario, 0);
      END IF;
      IF i.nro_doc_beneficiario IS NOT NULL
         AND i.cod_tip_doc_beneficiario IS NOT NULL THEN
        rp_stdet.tip_doc_beneficiario := fue_obt_tip_doc_abreviatura(i.cod_tip_doc_beneficiario);
        rp_stdet.nro_doc_beneficiario := i.nro_doc_beneficiario;
      ELSE
        lp_obt_dat_persona(NULL, v_cod_per_beneficiario, rp_stdet.tip_doc_beneficiario, rp_stdet.nro_doc_beneficiario);
      END IF;
      pre_obt_pai_iso(v_cod_per_beneficiario, NULL, NULL, rp_stdet.des_ciu_iso_destino, rp_stdet.cod_pai_iso_destino);
      --BSEVOCORE-904 El campo COD_PAI_ISO_DESTINO no debe ser nulo, y las Tranf. via SIPAP todas deben ser PY
      IF rp_stdet.cod_pai_iso_destino IS NULL THEN
        rp_stdet.cod_pai_iso_destino := 'PY';
      END IF;
      --Fin BSEVOCORE-904
      IF v_tip_entidad = 'F' THEN
        lp_obt_cod_swift(NULL, v_cod_entidad, rp_stdet.cod_swi_bco_intermediario);
        IF rp_stdet.cod_swi_bco_intermediario = i.cod_swi_pte_beneficiario THEN
          rp_stdet.cod_swi_bco_beneficiario := i.cod_swi_pte_beneficiario;
        ELSE
          rp_stdet.cod_swi_bco_beneficiario := rpad(i.cod_swi_pte_beneficiario, 11, 'X');
        END IF;
      ELSE
        --BSEVOCORE-904 Los BIC de FINANCIERAS no deben ser completados con X
        IF NOT pas_snp.fu_obt_ind_swi_propio(i.cod_swi_pte_solicitante) THEN
          rp_stdet.cod_swi_bco_intermediario := i.cod_swi_pte_solicitante;
        ELSE
          rp_stdet.cod_swi_bco_intermediario := rpad(i.cod_swi_pte_solicitante, 11, 'X');
        END IF;
        rp_stdet.cod_swi_bco_beneficiario := rpad(i.cod_swi_pte_beneficiario, 11, 'X');
      END IF;
      rp_stdet.tip_fondo        := fue_tab_dat_adicional('GE_SNP_TRANSFERENCIAS', 'SIB_TRA_ORI_FONDOS', i.nro_referencia);
      rp_stdet.tip_motivo       := fue_tab_dat_adicional('GE_SNP_TRANSFERENCIAS', 'SIB_TRA_MOTIVO', i.nro_referencia);
      rp_stdet.tip_financiacion := fue_tab_dat_adicional('GE_SNP_TRANSFERENCIAS', 'SIB_TRA_FINANCIACION', i.nro_referencia);
      IF rp_stdet.tip_fondo IS NULL
         OR rp_stdet.tip_motivo IS NULL
         OR rp_stdet.tip_financiacion IS NULL THEN
        v_val_parametro    := fug_obt_pardinamico('SIB_TRA_DAT_SNP_RECIBIDAS');
        rp_stdet.tip_fondo := pae_uti.fu_obt_valor(v_val_parametro, 1);
        --BSEVOCORE-904 por defecto del parametro viene 1, si es persona juridica debe ser 2
        IF i.cod_tip_doc_solicitante = 6 THEN
          --RUC
          rp_stdet.tip_fondo := 2;
        END IF;
        rp_stdet.tip_motivo       := pae_uti.fu_obt_valor(v_val_parametro, 2);
        rp_stdet.tip_financiacion := pae_uti.fu_obt_valor(v_val_parametro, 3);
      END IF;
      rp_stdet.tip_doc_transportadora := NULL;
      rp_stdet.nro_doc_transportadora := NULL;
      rp_stdet.autorizado             := fue_per_dat_adicional(i.cod_per_beneficiario, 'TRA_AUT_ENV_DATOS');
      IF v_cod_per_ordenante IS NULL
         OR v_cod_per_beneficiario IS NULL THEN
        IF i.nro_doc_solicitante <> i.nro_doc_beneficiario THEN
          v_nro_registro        := v_nro_registro + 1;
          rp_stdet.nro_registro := v_nro_registro;
          lp_ins_transferencias_det(rp_stdet);
        END IF;
      ELSIF v_cod_per_beneficiario <> v_cod_per_ordenante THEN
        v_nro_registro        := v_nro_registro + 1;
        rp_stdet.nro_registro := v_nro_registro;
        lp_ins_transferencias_det(rp_stdet);
      END IF;
    END LOOP;
  END;

  PROCEDURE lp_gen_tra_env_sipap IS
    v_tip_doc_ordenante VARCHAR2(10);
    v_ref_aux           VARCHAR2(100); 
    CURSOR c_transferencias IS
      SELECT nro_referencia,
             cod_oficina,
             cod_tip_operacion,
             cod_sub_tip_operacion,
             fec_valor,
             cod_moneda,
             monto,
             cod_per_solicitante,
             cod_tip_doc_solicitante,
             nro_doc_solicitante,
             nro_cta_solicitante,
             cod_swi_pte_solicitante,
             nro_cta_pte_solicitante,
             cod_per_beneficiario,
             cod_tip_doc_beneficiario,
             nro_doc_beneficiario,
             nro_cta_beneficiario,
             nro_cta_pte_beneficiario,
             cod_swi_pte_beneficiario,
             cod_swi_pte_intermediario,
             cod_msj_swift,
             nro_ref_externa,
             nro_operacion,
             cod_modulo,
             cod_modalidad
      FROM ge_snp_transferencias
      WHERE fec_valor = v_fec_actual
      AND nro_ref_externa IS NULL
      AND fec_recepcion IS NULL
      AND situacion = 'L'
      --and nro_referencia=240722989976
      AND estado = 'A'
      AND nvl(pag_gen.fu_con_mon_a_moneda(cod_moneda, v_cod_mon_local, monto, NULL, v_fec_actual, NULL), 0) >
            v_mto_minimo
      AND (cod_msj_swift = 202 AND cod_tip_operacion NOT IN ('003', '002') OR
            cod_msj_swift <> 202);
  BEGIN
    FOR i IN c_transferencias
    LOOP
      --dbms_output.put_line('> nro_referencia: '||i.nro_referencia);
      rp_stdet.fecha          := v_fec_actual;
      rp_stdet.tip_movimiento := 3;
      rp_stdet.tip_operacion  := 'L';
      rp_stdet.cod_oficina    := i.cod_oficina;
      rp_stdet.nro_operacion  := i.nro_referencia;
      rp_stdet.cod_mon_iso    := i.cod_moneda;
      rp_stdet.fec_operacion  := i.fec_valor;
      rp_stdet.cod_modulo     := i.cod_modulo;
      rp_stdet.cod_modalidad  := i.cod_modalidad;
      rp_stdet.monto          := i.monto;
      rp_stdet.val_conversion := fug_obt_cotizacion(i.cod_moneda, i.fec_valor);
      --solicitante
      IF i.cod_per_solicitante IS NULL THEN
        v_cod_per_ordenante := fue_obt_cod_persona_doc(i.cod_tip_doc_solicitante, i.nro_doc_solicitante);
        IF v_cod_per_ordenante IS NULL THEN
          BEGIN
            SELECT cod_persona
            INTO v_cod_per_ordenante
            FROM gv_snp_participantes
            WHERE cod_swift = i.cod_swi_pte_solicitante;
          EXCEPTION
            WHEN OTHERS THEN
              v_cod_per_ordenante := NULL;
          END;
        END IF;
      ELSE
        v_cod_per_ordenante := i.cod_per_solicitante;
      END IF;
      IF i.nro_doc_solicitante IS NOT NULL
         AND i.cod_tip_doc_solicitante IS NOT NULL THEN
         v_tip_doc_ordenante := fue_obt_tip_doc_abreviatura(i.cod_tip_doc_solicitante);

           IF v_tip_doc_ordenante = 'OJUD' THEN
              IF INSTR(i.nro_doc_solicitante, '-') > 0 THEN
                 rp_stdet.tip_doc_ordenante := 'RUC';
              ELSE
                 rp_stdet.tip_doc_ordenante := 'CI';
              END IF;
           ELSE
              -- Busca equivalencia definida --
              v_ref_aux := fue_obt_val_max_refcodes('SIB_TIP_DOC_BCP', v_tip_doc_ordenante);

              -- si no encontro por defecto CRC --
              IF v_ref_aux = 'Referencia no registrada en el Sistema' OR v_ref_aux IS NULL THEN
                rp_stdet.tip_doc_ordenante := 'CRC';
              ELSE
                rp_stdet.tip_doc_ordenante := v_ref_aux;
              END IF;
           END IF;
           rp_stdet.nro_doc_ordenante := i.nro_doc_solicitante;          
      ELSE
        lp_obt_dat_persona(NULL, v_cod_per_ordenante, rp_stdet.tip_doc_ordenante, rp_stdet.nro_doc_ordenante);
      END IF;
      rp_stdet.nro_cta_ordenante := i.nro_cta_solicitante;
      IF rp_stdet.nro_cta_ordenante IS NULL THEN
        rp_stdet.nro_cta_ordenante := nvl(i.nro_cta_pte_solicitante, 0);
      END IF;
      IF v_tip_entidad = 'F' THEN
        rp_stdet.cod_swi_bco_intermediario := i.cod_swi_pte_solicitante;
      ELSE
        --rp_stdet.cod_swi_bco_intermediario := rpad(i.cod_swi_pte_solicitante, 11, 'X');
        rp_stdet.cod_swi_bco_intermediario := rpad(i.cod_swi_pte_intermediario, 11, 'X');
      END IF;
      pre_obt_pai_iso(v_cod_per_ordenante, NULL, NULL, rp_stdet.des_ciu_iso_origen, rp_stdet.cod_pai_iso_origen);
      --BSEVOCORE-904 El campo COD_PAI_ISO_ORIGEN no debe ser nulo, y las Tranf. via SIPAP todas deben ser PY
      IF rp_stdet.cod_pai_iso_origen IS NULL THEN
        rp_stdet.cod_pai_iso_origen := 'PY';
      END IF;
      --Fin BSEVOCORE-904

      --beneficiario
      IF i.cod_per_beneficiario IS NULL THEN
        v_cod_per_beneficiario := fue_obt_cod_persona_doc(i.cod_tip_doc_beneficiario, i.nro_doc_beneficiario);
        IF v_cod_per_beneficiario IS NULL THEN
          BEGIN
            SELECT cod_persona
            INTO v_cod_per_beneficiario
            FROM gv_snp_participantes
            WHERE cod_swift = i.cod_swi_pte_beneficiario;
          EXCEPTION
            WHEN OTHERS THEN
              v_cod_per_beneficiario := NULL;
          END;
        END IF;
      ELSE
        v_cod_per_beneficiario := i.cod_per_beneficiario;
      END IF;
      pre_obt_pai_iso(v_cod_per_beneficiario, NULL, NULL, rp_stdet.des_ciu_iso_destino, rp_stdet.cod_pai_iso_destino);
      --BSEVOCORE-904 El campo COD_PAI_ISO_DESTINO no debe ser nulo, y las Tranf. via SIPAP todas deben ser PY
      IF rp_stdet.cod_pai_iso_destino IS NULL THEN
        rp_stdet.cod_pai_iso_destino := 'PY';
      END IF;
      --Fin BSEVOCORE-904

      IF i.nro_doc_beneficiario IS NOT NULL
         AND i.cod_tip_doc_beneficiario IS NOT NULL THEN
        rp_stdet.tip_doc_beneficiario := fue_obt_tip_doc_abreviatura(i.cod_tip_doc_beneficiario);
        rp_stdet.nro_doc_beneficiario := i.nro_doc_beneficiario;
      ELSE
        lp_obt_dat_persona(NULL, v_cod_per_beneficiario, rp_stdet.tip_doc_beneficiario, rp_stdet.nro_doc_beneficiario);
      END IF;
      rp_stdet.nro_cta_beneficiario := substr(i.nro_cta_beneficiario, 1, 30); --DYDMR-20458 se agrega substr por error en cierre 11/02/22 C.O
      IF rp_stdet.nro_cta_beneficiario IS NULL THEN
        rp_stdet.nro_cta_beneficiario := nvl(i.nro_cta_pte_beneficiario, 0);
      END IF;
      rp_stdet.tip_fondo        := fue_tab_dat_adicional('GE_SNP_TRANSFERENCIAS', 'SIB_TRA_ORI_FONDOS', i.nro_referencia);
      begin
        select to_number(fue_tab_dat_adicional('GE_SNP_TRANSFERENCIAS', 'SIB_TRA_MOTIVO', i.nro_referencia)) * 1
          into rp_stdet.tip_motivo
        from dual;
        rp_stdet.tip_motivo      := fue_tab_dat_adicional('GE_SNP_TRANSFERENCIAS', 'SIB_TRA_MOTIVO', i.nro_referencia);
      exception
        when others then
          rp_stdet.tip_motivo       := null;
      end;
      --rp_stdet.tip_motivo       := fue_tab_dat_adicional('GE_SNP_TRANSFERENCIAS', 'SIB_TRA_MOTIVO', i.nro_referencia);
      rp_stdet.tip_financiacion := fue_tab_dat_adicional('GE_SNP_TRANSFERENCIAS', 'SIB_TRA_FINANCIACION', i.nro_referencia);
      IF rp_stdet.tip_fondo IS NULL
         OR rp_stdet.tip_motivo IS NULL
         OR rp_stdet.tip_financiacion IS NULL THEN
        rp_stdet.tip_fondo := fu_obt_ori_fondo(rp_stdet.nro_doc_ordenante);
        IF v_cod_entidad = 1007 THEN
          rp_stdet.tip_motivo       := 10; --servicio recibido en el paraguay
          rp_stdet.tip_financiacion := 2; --deposito a cargo banco declarante
        ELSIF v_cod_entidad = 1028 THEN
          rp_stdet.tip_financiacion := 1; --Efectivo
        END IF;
      END IF;
      /* SPPARPAT-2 Transferencias Participante Patrocinador */
      IF i.cod_msj_swift = 103
         AND i.cod_tip_operacion = '001'
         AND i.cod_sub_tip_operacion = '004' THEN
        --BSEVOCORE-904 se asigna el swfit del sub participante
        rp_stdet.cod_swi_bco_beneficiario := i.cod_swi_pte_beneficiario;
        /* Fin SPPARPAT-2 */
      ELSIF NOT pas_snp.fu_obt_ind_swi_propio(i.cod_swi_pte_beneficiario) THEN
        rp_stdet.cod_swi_bco_beneficiario := i.cod_swi_pte_beneficiario;
      ELSE
        rp_stdet.cod_swi_bco_beneficiario := rpad(i.cod_swi_pte_beneficiario, 11, 'X');
      END IF;
      rp_stdet.tip_doc_transportadora := NULL;
      rp_stdet.nro_doc_transportadora := NULL;
      rp_stdet.autorizado             := fue_per_dat_adicional(i.cod_per_beneficiario, 'TRA_AUT_ENV_DATOS');
      IF v_cod_per_ordenante IS NULL
         OR v_cod_per_beneficiario IS NULL THEN
        IF i.nro_doc_solicitante <> i.nro_doc_beneficiario THEN
          v_nro_registro        := v_nro_registro + 1;
          rp_stdet.nro_registro := v_nro_registro;
          lp_ins_transferencias_det(rp_stdet);
        END IF;
      ELSIF v_cod_per_ordenante <> v_cod_per_beneficiario THEN
        v_nro_registro        := v_nro_registro + 1;
        rp_stdet.nro_registro := v_nro_registro;
        lp_ins_transferencias_det(rp_stdet);
      END IF;
    END LOOP;
  END;

  PROCEDURE lp_gen_tra_importaciones IS
    CURSOR c_movimientos IS
      SELECT g.fecha, g.cod_ofi_origen, g.monto, g.nro_cuenta
      FROM ge_movimientos g
      WHERE g.cod_mod_padre = 8
      AND g.cod_mad_padre = 81
      AND g.cod_tra_padre = 368
      AND g.cod_transaccion = 773
      AND g.reversado = 'N'
      AND g.estado = 'N'
      AND g.fecha = v_fec_actual;
    CURSOR c_cuentas IS
      SELECT nro_cuenta,
             cod_oficina,
             cod_moneda,
             cod_bco_corresponsal,
             cod_bco_negociador,
             nro_referencia,
             nro_cta_credito,
             cod_pais,
             cod_ciudad
      FROM cx_cta_importaciones x
      WHERE x.nro_cuenta = v_nro_cuenta;
  BEGIN
    FOR i IN c_movimientos
    LOOP
      v_nro_cuenta            := i.nro_cuenta;
      rp_stdet.tip_movimiento := 2;
      rp_stdet.tip_operacion  := 'E';
      rp_stdet.cod_modulo     := 8;
      rp_stdet.cod_modalidad  := 81;
      rp_stdet.fecha          := v_fec_actual;
      FOR j IN c_cuentas
      LOOP
        rp_stdet.cod_oficina   := i.cod_ofi_origen;
        rp_stdet.nro_operacion := j.nro_cuenta;
        rp_stdet.cod_mon_iso   := j.cod_moneda;
        rp_stdet.fec_operacion := i.fecha;
        lp_obt_dat_persona(i.nro_cuenta, v_cod_persona, rp_stdet.tip_doc_ordenante, rp_stdet.nro_doc_ordenante);
        pre_obt_pai_iso(v_cod_persona, NULL, NULL, rp_stdet.des_ciu_iso_origen, rp_stdet.cod_pai_iso_origen);
        rp_stdet.nro_cta_ordenante := nvl(j.nro_cuenta, 0);
        rp_stdet.monto             := i.monto;
        rp_stdet.val_conversion    := fug_obt_cotizacion(j.cod_moneda, i.fecha);
        lp_obt_cod_swift(NULL, v_cod_entidad, rp_stdet.cod_swi_bco_intermediario);
        rp_stdet.cod_swi_bco_beneficiario := NULL;
        rp_stdet.nro_cta_beneficiario     := nvl(j.nro_cta_credito, 0);
        v_val_parametro                   := fug_obt_pardinamico('SIB_TRA_DAT_COMEX');
        rp_stdet.tip_fondo                := pae_uti.fu_obt_valor(v_val_parametro, 1);
        rp_stdet.tip_motivo               := pae_uti.fu_obt_valor(v_val_parametro, 2);
        rp_stdet.tip_financiacion         := pae_uti.fu_obt_valor(v_val_parametro, 3);
        rp_stdet.tip_doc_transportadora   := NULL;
        rp_stdet.nro_doc_transportadora   := NULL;
        rp_stdet.autorizado               := fue_per_dat_adicional(v_cod_persona, 'TRA_AUT_ENV_DATOS');
        rp_stdet.nro_doc_beneficiario     := NULL;
        rp_stdet.tip_doc_beneficiario     := NULL;
        pre_obt_pai_iso(NULL, j.cod_pais, j.cod_ciudad, rp_stdet.des_ciu_iso_destino, rp_stdet.cod_pai_iso_destino);
      END LOOP;
      v_nro_registro        := v_nro_registro + 1;
      rp_stdet.nro_registro := v_nro_registro;
      lp_ins_transferencias_det(rp_stdet);
    END LOOP;
  END;

  PROCEDURE lp_gen_tra_exportaciones IS
    CURSOR c_movimientos IS
      SELECT g.fecha,
             g.cod_ofi_origen,
             g.monto,
             g.nro_cuenta,
             g.cod_modulo,
             g.cod_modalidad
      FROM ge_movimientos g
      WHERE g.cod_mod_padre = 8
      AND g.cod_mad_padre = 82
      AND g.cod_tra_padre = 384
      AND g.cod_transaccion = 773
      AND g.reversado = 'N'
      AND g.estado = 'N'
      AND g.fecha = v_fec_actual;
    CURSOR c_cuentas IS
      SELECT nro_cuenta,
             cod_oficina,
             cod_moneda,
             monto,
             cod_bco_emisor,
             cod_bco_corresponsal,
             cod_per_beneficiario,
             nro_referencia
      FROM cx_cta_exportaciones x
      WHERE x.nro_cuenta = v_nro_cuenta;
  BEGIN
    FOR i IN c_movimientos
    LOOP
      rp_stdet.tip_movimiento := 1;
      rp_stdet.tip_operacion  := 'R';
      v_nro_cuenta            := i.nro_cuenta;
      rp_stdet.cod_modulo     := i.cod_modulo;
      rp_stdet.cod_modalidad  := i.cod_modalidad;
      rp_stdet.fecha          := v_fec_actual;
      FOR j IN c_cuentas
      LOOP
        rp_stdet.cod_oficina       := i.cod_ofi_origen;
        rp_stdet.nro_operacion     := j.nro_cuenta;
        rp_stdet.cod_mon_iso       := j.cod_moneda;
        rp_stdet.fec_operacion     := i.fecha;
        rp_stdet.tip_doc_ordenante := NULL;
        rp_stdet.nro_doc_ordenante := NULL;
        rp_stdet.nro_cta_ordenante := nvl(j.nro_cuenta, 0);
        rp_stdet.monto             := i.monto;
        rp_stdet.val_conversion    := fug_obt_cotizacion(j.cod_moneda, i.fecha);
        v_cod_persona              := lf_obt_per_banco(j.cod_bco_corresponsal);
        lp_obt_cod_swift(NULL, v_cod_entidad, rp_stdet.cod_swi_bco_beneficiario);
        pre_obt_pai_iso(v_cod_persona, NULL, NULL, rp_stdet.des_ciu_iso_origen, rp_stdet.cod_pai_iso_origen);
        lp_obt_cod_swift(j.cod_bco_emisor, NULL, rp_stdet.cod_swi_bco_intermediario);
        rp_stdet.nro_cta_beneficiario   := nvl(j.nro_referencia, 0);
        v_val_parametro                 := fug_obt_pardinamico('SIB_TRA_DAT_COMEX');
        rp_stdet.tip_fondo              := pae_uti.fu_obt_valor(v_val_parametro, 1);
        rp_stdet.tip_motivo             := pae_uti.fu_obt_valor(v_val_parametro, 2);
        rp_stdet.tip_financiacion       := pae_uti.fu_obt_valor(v_val_parametro, 3);
        rp_stdet.tip_doc_transportadora := NULL;
        rp_stdet.nro_doc_transportadora := NULL;
        rp_stdet.autorizado             := fue_per_dat_adicional(v_cod_persona, 'TRA_AUT_ENV_DATOS');
        lp_obt_dat_persona(NULL, j.cod_per_beneficiario, rp_stdet.tip_doc_beneficiario, rp_stdet.nro_doc_beneficiario);
        pre_obt_pai_iso(j.cod_per_beneficiario, NULL, NULL, rp_stdet.des_ciu_iso_destino, rp_stdet.cod_pai_iso_destino);
      END LOOP;
      v_nro_registro        := v_nro_registro + 1;
      rp_stdet.nro_registro := v_nro_registro;
      lp_ins_transferencias_det(rp_stdet);
    END LOOP;
  END;

  PROCEDURE lp_gen_tra_cob_importacion IS
    CURSOR c_movimientos IS
      SELECT g.fecha, g.cod_ofi_origen, g.monto, g.nro_cuenta
      FROM ge_movimientos g
      WHERE g.cod_mod_padre = 8
      AND g.cod_mad_padre = 83
      AND g.cod_tra_padre = 368
      AND g.cod_transaccion = 773
      AND g.reversado = 'N'
      AND g.estado = 'N'
      AND g.fecha = v_fec_actual;
    CURSOR c_cuentas IS
      SELECT nro_cuenta,
             cod_oficina,
             cod_moneda,
             monto,
             cod_banco,
             cod_bco_corresponsal,
             cod_per_beneficiario,
             nro_doc_beneficiario,
             cod_pai_beneficiario,
             cod_ciu_beneficiario,
             nro_ref_externa
      FROM cx_cta_cobranzas x
      WHERE x.nro_cuenta = v_nro_cuenta;
  BEGIN
    FOR i IN c_movimientos
    LOOP
      v_nro_cuenta            := i.nro_cuenta;
      rp_stdet.tip_movimiento := 2;
      rp_stdet.tip_operacion  := 'E';
      rp_stdet.cod_modulo     := 8;
      rp_stdet.cod_modalidad  := 83;
      rp_stdet.fecha          := v_fec_actual;
      FOR j IN c_cuentas
      LOOP
        rp_stdet.cod_oficina   := i.cod_ofi_origen;
        rp_stdet.nro_operacion := j.nro_cuenta;
        rp_stdet.cod_mon_iso   := j.cod_moneda;
        rp_stdet.fec_operacion := i.fecha;
        lp_obt_dat_persona(i.nro_cuenta, v_cod_persona, rp_stdet.tip_doc_ordenante, rp_stdet.nro_doc_ordenante);
        pre_obt_pai_iso(v_cod_persona, NULL, NULL, rp_stdet.des_ciu_iso_origen, rp_stdet.cod_pai_iso_origen);
        rp_stdet.nro_cta_ordenante := nvl(j.nro_cuenta, 0);
        rp_stdet.monto             := i.monto;
        rp_stdet.val_conversion    := fug_obt_cotizacion(j.cod_moneda, i.fecha);
        lp_obt_cod_swift(NULL, v_cod_entidad, rp_stdet.cod_swi_bco_intermediario);
        lp_obt_cod_swift(j.cod_banco, NULL, rp_stdet.cod_swi_bco_beneficiario);
        rp_stdet.nro_cta_beneficiario   := nvl(j.nro_cuenta, 0);
        v_val_parametro                 := fug_obt_pardinamico('SIB_TRA_DAT_IMP_COBRANZAS');
        rp_stdet.tip_fondo              := pae_uti.fu_obt_valor(v_val_parametro, 1);
        rp_stdet.tip_motivo             := pae_uti.fu_obt_valor(v_val_parametro, 2);
        rp_stdet.tip_financiacion       := pae_uti.fu_obt_valor(v_val_parametro, 3);
        rp_stdet.tip_doc_transportadora := NULL;
        rp_stdet.nro_doc_transportadora := NULL;
        rp_stdet.autorizado             := fue_per_dat_adicional(v_cod_persona, 'TRA_AUT_ENV_DATOS');
        rp_stdet.nro_doc_beneficiario   := j.nro_doc_beneficiario;
        lp_obt_dat_persona(NULL, j.cod_per_beneficiario, rp_stdet.tip_doc_beneficiario, rp_stdet.nro_doc_beneficiario);
        rp_stdet.nro_doc_beneficiario := j.nro_doc_beneficiario;
        pre_obt_pai_iso(NULL, j.cod_pai_beneficiario, j.cod_ciu_beneficiario, rp_stdet.des_ciu_iso_destino, rp_stdet.cod_pai_iso_destino);
      END LOOP;
      v_nro_registro        := v_nro_registro + 1;
      rp_stdet.nro_registro := v_nro_registro;
      lp_ins_transferencias_det(rp_stdet);
    END LOOP;
  END;

  PROCEDURE lp_gen_tra_cob_exportacion IS
    CURSOR c_movimientos IS
      SELECT g.fecha,
             g.cod_ofi_origen,
             g.monto,
             g.nro_cuenta,
             g.cod_modulo,
             g.cod_modalidad
      FROM ge_movimientos g
      WHERE g.cod_mod_padre = 8
      AND g.cod_mad_padre = 84
      AND g.cod_tra_padre = 368
      AND g.cod_transaccion = 773
      AND g.reversado = 'N'
      AND g.estado = 'N'
      AND g.fecha = v_fec_actual;
    CURSOR c_cuentas IS
      SELECT nro_cuenta,
             cod_oficina,
             cod_moneda,
             monto,
             cod_banco,
             cod_bco_corresponsal,
             cod_pai_beneficiario,
             cod_ciu_beneficiario,
             cod_pai_pagador,
             cod_ciu_pagador,
             nro_ref_externa,
             nro_doc_pagador
      FROM cx_cta_cobranzas x
      WHERE x.nro_cuenta = v_nro_cuenta;
  BEGIN
    FOR i IN c_movimientos
    LOOP
      v_nro_cuenta            := i.nro_cuenta;
      rp_stdet.cod_modulo     := i.cod_modulo;
      rp_stdet.cod_modalidad  := i.cod_modalidad;
      rp_stdet.fecha          := v_fec_actual;
      rp_stdet.tip_movimiento := 1;
      rp_stdet.tip_operacion  := 'R';
      FOR j IN c_cuentas
      LOOP
        rp_stdet.cod_oficina       := i.cod_ofi_origen;
        rp_stdet.nro_operacion     := j.nro_cuenta;
        rp_stdet.cod_mon_iso       := j.cod_moneda;
        rp_stdet.fec_operacion     := i.fecha;
        rp_stdet.tip_doc_ordenante := NULL;
        rp_stdet.nro_doc_ordenante := j.nro_doc_pagador;
        rp_stdet.nro_cta_ordenante := nvl(j.nro_cuenta, 0);
        rp_stdet.monto             := i.monto;
        rp_stdet.val_conversion    := fug_obt_cotizacion(j.cod_moneda, i.fecha);
        lp_obt_cod_swift(j.cod_bco_corresponsal, NULL, rp_stdet.cod_swi_bco_intermediario);
        pre_obt_pai_iso(NULL, j.cod_pai_pagador, j.cod_ciu_pagador, rp_stdet.des_ciu_iso_origen, rp_stdet.cod_pai_iso_origen);
        --lp_obt_cod_swift(j.cod_banco, NULL, rp_stdet.cod_swi_bco_beneficiario);
        --BSEVOCORE-904 Para transferencias recibidas, el beneficiario debe ser el banco.
        rp_stdet.cod_swi_bco_beneficiario := rpad(v_swi_banco, 11, 'X');
        rp_stdet.nro_cta_beneficiario     := nvl(j.nro_cuenta, 0);
        v_val_parametro                   := fug_obt_pardinamico('SIB_TRA_DAT_EXP_COBRANZAS');
        rp_stdet.tip_fondo                := pae_uti.fu_obt_valor(v_val_parametro, 1);
        rp_stdet.tip_motivo               := pae_uti.fu_obt_valor(v_val_parametro, 2);
        rp_stdet.tip_financiacion         := pae_uti.fu_obt_valor(v_val_parametro, 3);
        rp_stdet.tip_doc_transportadora   := NULL;
        rp_stdet.nro_doc_transportadora   := NULL;
        lp_obt_dat_persona(j.nro_cuenta, v_cod_persona, rp_stdet.tip_doc_beneficiario, rp_stdet.nro_doc_beneficiario);
        rp_stdet.autorizado := fue_per_dat_adicional(v_cod_persona, 'TRA_AUT_ENV_DATOS');
        pre_obt_pai_iso(v_cod_persona, NULL, NULL, rp_stdet.des_ciu_iso_destino, rp_stdet.cod_pai_iso_destino);
      END LOOP;
      v_nro_registro        := v_nro_registro + 1;
      rp_stdet.nro_registro := v_nro_registro;
      lp_ins_transferencias_det(rp_stdet);
    END LOOP;
  END;

  PROCEDURE lp_gen_tra_ven_divisas IS
    CURSOR c_movimientos IS
      SELECT DISTINCT g.fecha, g.hora, g.cod_usuario
      FROM ge_movimientos g
      WHERE g.cod_tra_padre = 265
      AND cod_mod_padre = 7
      AND cod_mad_padre = 72
      AND g.cod_transaccion IN (503, 602)
      AND g.reversado = 'N'
      AND g.estado = 'N'
      AND g.nro_secuencia < 900
      AND g.fecha = v_fec_actual;
    CURSOR c_cuentas IS
      SELECT fecha,
             monto,
             nro_cuenta,
             cod_moneda,
             cod_ofi_origen,
             cod_transaccion,
             nro_documento,
             referencia
      FROM ge_movimientos
      WHERE fecha = v_fecha
      AND hora = v_hora
      AND cod_usuario = v_cod_usuario
      AND nro_secuencia < 900;
  BEGIN
    rp_stdet.tip_movimiento := 2;
    FOR i IN c_movimientos
    LOOP
      v_fecha       := i.fecha;
      v_hora        := i.hora;
      v_cod_usuario := i.cod_usuario;
      FOR j IN c_cuentas
      LOOP
        IF nvl(j.cod_transaccion, 0) = 503 THEN
          -- débito/origen
          lp_obt_dat_persona(j.nro_cuenta, v_cod_persona, rp_stdet.tip_doc_ordenante, rp_stdet.nro_doc_ordenante);
          pre_obt_pai_iso(v_cod_persona, NULL, NULL, rp_stdet.des_ciu_iso_origen, rp_stdet.cod_pai_iso_origen);
          rp_stdet.nro_cta_ordenante := nvl(j.nro_cuenta, 0);
          rp_stdet.autorizado        := fue_per_dat_adicional(v_cod_persona, 'TRA_AUT_ENV_DATOS');
        ELSIF nvl(j.cod_transaccion, 0) = 602 THEN
          -- destino/credito
          rp_stdet.fecha                     := v_fec_actual;
          rp_stdet.cod_oficina               := j.cod_ofi_origen;
          rp_stdet.nro_operacion             := j.nro_documento;
          rp_stdet.cod_mon_iso               := j.cod_moneda;
          rp_stdet.fec_operacion             := j.fecha;
          rp_stdet.monto                     := j.monto;
          rp_stdet.val_conversion            := fug_obt_cotizacion(j.cod_moneda, j.fecha);
          rp_stdet.cod_swi_bco_intermediario := NULL;
          rp_stdet.cod_swi_bco_beneficiario  := NULL;
          rp_stdet.tip_doc_transportadora    := NULL;
          rp_stdet.nro_doc_transportadora    := NULL;
          v_val_parametro                    := fug_obt_pardinamico('SIB_TRA_DAT_VENTA');
          rp_stdet.tip_fondo                 := pae_uti.fu_obt_valor(v_val_parametro, 1);
          rp_stdet.tip_motivo                := pae_uti.fu_obt_valor(v_val_parametro, 2);
          rp_stdet.tip_financiacion          := pae_uti.fu_obt_valor(v_val_parametro, 3);
          lp_obt_dat_persona(j.nro_cuenta, v_cod_persona, rp_stdet.tip_doc_beneficiario, rp_stdet.nro_doc_beneficiario);
          pre_obt_pai_iso(v_cod_persona, NULL, NULL, rp_stdet.des_ciu_iso_destino, rp_stdet.cod_pai_iso_destino);
          rp_stdet.nro_cta_beneficiario := nvl(j.nro_cuenta, 0);
        END IF;
      END LOOP;
      v_nro_registro        := v_nro_registro + 1;
      rp_stdet.nro_registro := v_nro_registro;
      lp_ins_transferencias_det(rp_stdet);
    END LOOP;
  END;

  PROCEDURE lp_gen_tra_com_divisas IS
    CURSOR c_movimientos IS
      SELECT DISTINCT g.fecha, g.hora, g.cod_usuario
      FROM ge_movimientos g
      WHERE g.cod_tra_padre = 255
      AND cod_mod_padre = 7
      AND cod_mad_padre = 71
      AND g.cod_transaccion IN (503, 602)
      AND g.reversado = 'N'
      AND g.estado = 'N'
      AND g.cod_tip_ope_cambio = 16
      AND nvl(pag_gen.fu_con_mon_a_moneda(g.cod_moneda, v_cod_mon_local, g.monto, NULL, v_fec_actual, NULL), 0) >
            v_mto_minimo
      AND g.nro_secuencia < 900
      AND g.fecha = v_fec_actual
      AND EXISTS (SELECT hora
             FROM ge_movimientos
             WHERE cod_tra_padre = 255
             AND cod_mod_padre = 7
             AND cod_mad_padre = 71
             AND reversado = 'N'
             AND estado = 'N'
             AND cod_transaccion IN (503, 602)
             AND nro_secuencia < 900
             AND fecha = g.fecha
             AND hora = g.hora
             AND cod_tip_ope_cambio = 3
             AND g.nro_documento = nro_documento);
    CURSOR c_cuentas IS
      SELECT fecha,
             monto,
             nro_cuenta,
             cod_moneda,
             cod_ofi_origen,
             cod_transaccion,
             nro_documento,
             referencia,
             cod_persona,
             cod_modulo,
             cod_modalidad
      FROM ge_movimientos
      WHERE fecha = v_fecha
      AND hora = v_hora
      AND cod_usuario = v_cod_usuario
      AND cod_tra_padre = 255
      AND cod_mod_padre = 7
      AND cod_mad_padre = 71
      AND cod_transaccion IN (503, 602)
      AND nro_secuencia < 900;
  BEGIN
    FOR i IN c_movimientos
    LOOP
      v_fecha                 := i.fecha;
      v_hora                  := i.hora;
      v_cod_usuario           := i.cod_usuario;
      rp_stdet.tip_movimiento := 1;
      rp_stdet.tip_operacion  := 'L';
      rp_stdet.fecha          := v_fec_actual;
      v_cod_per_ordenante     := NULL;
      v_cod_per_beneficiario  := NULL;
      FOR j IN c_cuentas
      LOOP
        IF nvl(j.cod_transaccion, 0) = 503 THEN
          -- débito/origen
          rp_stdet.cod_oficina    := j.cod_ofi_origen;
          rp_stdet.nro_operacion  := j.nro_documento;
          rp_stdet.cod_mon_iso    := j.cod_moneda;
          rp_stdet.fec_operacion  := j.fecha;
          rp_stdet.monto          := j.monto;
          rp_stdet.cod_modulo     := j.cod_modulo;
          rp_stdet.cod_modalidad  := j.cod_modalidad;
          rp_stdet.val_conversion := fug_obt_cotizacion(j.cod_moneda, j.fecha);
          lp_obt_dat_persona(NULL, j.cod_persona, rp_stdet.tip_doc_ordenante, rp_stdet.nro_doc_ordenante);
          pre_obt_pai_iso(j.cod_persona, NULL, NULL, rp_stdet.des_ciu_iso_origen, rp_stdet.cod_pai_iso_origen);
          rp_stdet.nro_cta_ordenante := nvl(j.nro_cuenta, 0);
          lp_obt_cod_swift(NULL, v_cod_entidad, rp_stdet.cod_swi_bco_intermediario);
          rp_stdet.cod_swi_bco_beneficiario := NULL;
          rp_stdet.tip_doc_transportadora   := NULL;
          rp_stdet.nro_doc_transportadora   := NULL;
          v_val_parametro                   := fug_obt_pardinamico('SIB_TRA_DAT_COMPRA');
          rp_stdet.tip_fondo                := pae_uti.fu_obt_valor(v_val_parametro, 1);
          rp_stdet.tip_motivo               := pae_uti.fu_obt_valor(v_val_parametro, 2);
          rp_stdet.tip_financiacion         := pae_uti.fu_obt_valor(v_val_parametro, 3);
          rp_stdet.autorizado               := fue_per_dat_adicional(j.cod_persona, 'TRA_AUT_ENV_DATOS');
          v_cod_per_ordenante               := j.cod_persona;
        ELSIF nvl(j.cod_transaccion, 0) = 602 THEN
          -- destino/credito
          rp_stdet.nro_operacion := j.nro_documento;
          lp_obt_dat_persona(j.nro_cuenta, v_cod_per_beneficiario, rp_stdet.tip_doc_beneficiario, rp_stdet.nro_doc_beneficiario);
          pre_obt_pai_iso(v_cod_per_beneficiario, NULL, NULL, rp_stdet.des_ciu_iso_destino, rp_stdet.cod_pai_iso_destino);
          rp_stdet.nro_cta_beneficiario := nvl(j.nro_cuenta, 0);
        END IF;
      END LOOP;
      IF v_cod_per_ordenante <> v_cod_per_beneficiario
         AND (lf_obt_cta_interdepartamental(v_cod_per_ordenante) <>
         lf_obt_cta_interdepartamental(v_cod_per_beneficiario)) THEN
        v_nro_registro        := v_nro_registro + 1;
        rp_stdet.nro_registro := v_nro_registro;
        lp_ins_transferencias_det(rp_stdet);
      END IF;
    END LOOP;
  END;

  PROCEDURE lp_gen_tra_exp_divisas IS
    CURSOR c_divisas IS
      SELECT nro_referencia,
             cod_oficina,
             fec_operacion,
             nro_operacion,
             cod_moneda,
             monto,
             nro_cta_referencia,
             cod_banco,
             cod_pai_banco,
             cod_ciu_banco,
             cod_swi_banco,
             cod_bco_corresponsal,
             cod_per_solicitante,
             cod_pai_solicitante,
             cod_ciu_solicitante,
             cod_per_beneficiario,
             cod_pai_beneficiario,
             cod_ciu_beneficiario,
             nro_ref_externa,
             nro_doc_beneficiario,
             tip_fondo,
             tip_motivo,
             tip_financiacion,
             msj_swift,
             cod_modulo,
             cod_modalidad
      FROM sv_tra_exp_divisas
      WHERE fecha = v_fec_actual;
  BEGIN
    FOR i IN c_divisas
    LOOP
      rp_stdet.fecha             := v_fec_actual;
      rp_stdet.tip_movimiento    := 4;
      rp_stdet.tip_operacion     := 'X';
      rp_stdet.cod_modulo        := i.cod_modulo;
      rp_stdet.cod_modalidad     := i.cod_modalidad;
      rp_stdet.cod_oficina       := i.cod_oficina;
      rp_stdet.nro_operacion     := i.nro_operacion;
      rp_stdet.cod_mon_iso       := i.cod_moneda;
      rp_stdet.fec_operacion     := i.fec_operacion;
      rp_stdet.monto             := i.monto;
      rp_stdet.nro_cta_ordenante := NULL;
      rp_stdet.val_conversion    := fug_obt_cotizacion(i.cod_moneda, i.fec_operacion);
      lp_obt_dat_persona(NULL, v_cod_per_entidad, rp_stdet.tip_doc_ordenante, rp_stdet.nro_doc_ordenante);
      IF v_cod_entidad = 2079 THEN
        v_cod_persona := lf_obt_per_banco(i.cod_bco_corresponsal);
        lp_obt_cod_swift(i.cod_bco_corresponsal, NULL, rp_stdet.cod_swi_bco_intermediario);
        pre_obt_pai_iso(v_cod_persona, NULL, NULL, rp_stdet.des_ciu_iso_origen, rp_stdet.cod_pai_iso_origen);
      ELSE
        lp_obt_cod_swift(NULL, v_cod_entidad, rp_stdet.cod_swi_bco_intermediario);
        pre_obt_pai_iso(v_cod_per_entidad, NULL, NULL, rp_stdet.des_ciu_iso_origen, rp_stdet.cod_pai_iso_origen);
      END IF;
      lp_obt_cod_swift(i.cod_bco_corresponsal, NULL, rp_stdet.cod_swi_bco_beneficiario);
      rp_stdet.tip_fondo        := i.tip_fondo;
      rp_stdet.tip_motivo       := i.tip_motivo;
      rp_stdet.tip_financiacion := i.tip_financiacion;
      IF rp_stdet.tip_fondo IS NULL
         OR rp_stdet.tip_motivo IS NULL
         OR rp_stdet.tip_financiacion IS NULL THEN
        v_val_parametro           := fug_obt_pardinamico('SIB_TRA_EXP_DIVISAS');
        rp_stdet.tip_fondo        := pae_uti.fu_obt_valor(v_val_parametro, 1);
        rp_stdet.tip_motivo       := pae_uti.fu_obt_valor(v_val_parametro, 2);
        rp_stdet.tip_financiacion := pae_uti.fu_obt_valor(v_val_parametro, 3);
      END IF;
      rp_stdet.tip_doc_transportadora := NULL;
      rp_stdet.nro_doc_transportadora := NULL;
      rp_stdet.nro_cta_beneficiario   := nvl(i.nro_cta_referencia, 0);
      IF i.cod_per_beneficiario IS NOT NULL THEN
        lp_obt_dat_persona(NULL, i.cod_per_beneficiario, rp_stdet.tip_doc_beneficiario, rp_stdet.nro_doc_beneficiario);
        pre_obt_pai_iso(i.cod_per_beneficiario, NULL, NULL, rp_stdet.des_ciu_iso_destino, rp_stdet.cod_pai_iso_destino);
      ELSE
        rp_stdet.tip_doc_beneficiario := NULL;
        rp_stdet.nro_doc_beneficiario := i.nro_doc_beneficiario;
        pre_obt_pai_iso(NULL, i.cod_pai_beneficiario, i.cod_ciu_beneficiario, rp_stdet.des_ciu_iso_destino, rp_stdet.cod_pai_iso_destino);
      END IF;
      rp_stdet.autorizado   := fue_per_dat_adicional(i.cod_per_beneficiario, 'TRA_AUT_ENV_DATOS');
      v_nro_registro        := v_nro_registro + 1;
      rp_stdet.nro_registro := v_nro_registro;
      lp_ins_transferencias_det(rp_stdet);
    END LOOP;
  END;

  PROCEDURE lp_tra_ext_corresponsales IS
    v_nro_documento ge_movimientos.nro_documento%TYPE;
    v_cod_banco     ge_bancos.cod_banco%TYPE;
    CURSOR c_movimientos IS
      SELECT DISTINCT g.fecha, g.hora, g.cod_usuario, g.nro_documento
      FROM ge_movimientos g
      WHERE g.cod_tra_padre = 309
      AND g.cod_modalidad = 45
      AND g.reversado = 'N'
      AND g.estado = 'N'
      AND g.cod_transaccion = 602
      AND monto > 0
      AND g.fecha = v_fec_actual
      AND g.nro_secuencia < 900
      AND EXISTS (SELECT hora
             FROM ge_movimientos
             WHERE reversado = 'N'
             AND estado = 'N'
             AND cod_modalidad = 45
             AND cod_transaccion = 503
             AND nro_secuencia < 900
             AND fecha = g.fecha
             AND hora = g.hora
             AND cod_usuario = g.cod_usuario
             AND g.nro_documento = nro_documento);
    CURSOR c_cuentas IS
      SELECT g.fecha,
             g.nro_cuenta,
             g.cod_ofi_origen,
             g.cod_transaccion,
             g.nro_documento,
             g.monto,
             g.cod_moneda,
             g.cod_tra_padre,
             g.cod_mod_padre,
             g.cod_mad_padre,
             g.referencia,
             g.cod_modulo,
             g.cod_modalidad
      FROM ge_movimientos g
      WHERE g.fecha = v_fecha
      AND g.hora = v_hora
      AND g.cod_usuario = v_cod_usuario
      AND g.nro_documento = v_nro_documento
      AND g.nro_secuencia < 900
      AND ((g.cod_modalidad = 45 AND g.cod_transaccion = 602) OR
            (g.cod_modalidad = 45 AND g.cod_transaccion = 503));
  BEGIN
    FOR i IN c_movimientos
    LOOP
      v_fecha                 := i.fecha;
      v_hora                  := i.hora;
      v_cod_usuario           := i.cod_usuario;
      v_nro_documento         := i.nro_documento;
      rp_stdet.tip_movimiento := 4;
      rp_stdet.tip_operacion  := 'N';
      rp_stdet.fecha          := v_fec_actual;
      FOR j IN c_cuentas
      LOOP
        IF nvl(j.cod_transaccion, 0) = 503 THEN
          -- débito/origen
          rp_stdet.cod_modulo    := j.cod_modulo;
          rp_stdet.cod_modalidad := j.cod_modalidad;
          rp_stdet.cod_oficina   := j.cod_ofi_origen;
          rp_stdet.cod_mon_iso   := j.cod_moneda;
          rp_stdet.nro_operacion := j.nro_documento;
          rp_stdet.fec_operacion := j.fecha;
          v_cod_banco            := lf_obt_cod_banco(j.nro_cuenta);
          v_cod_persona          := lf_obt_per_banco(v_cod_banco);
          lp_obt_dat_persona(NULL, v_cod_persona, rp_stdet.tip_doc_ordenante, rp_stdet.nro_doc_ordenante);
          pre_obt_pai_iso(v_cod_persona, NULL, NULL, rp_stdet.des_ciu_iso_origen, rp_stdet.cod_pai_iso_origen);
          rp_stdet.nro_cta_ordenante := nvl(j.nro_cuenta, 0);
          rp_stdet.monto             := j.monto;
          rp_stdet.val_conversion    := fug_obt_cotizacion(j.cod_moneda, j.fecha);
          lp_obt_cod_swift(v_cod_banco, NULL, rp_stdet.cod_swi_bco_intermediario);
          lp_obt_dat_referencia(j.referencia, rp_stdet.tip_fondo, rp_stdet.tip_motivo, rp_stdet.tip_financiacion);
          rp_stdet.tip_doc_transportadora := NULL;
          rp_stdet.nro_doc_transportadora := NULL;
        ELSIF nvl(j.cod_transaccion, 0) = 602 THEN
          -- destino/credito
          v_cod_banco   := lf_obt_cod_banco(j.nro_cuenta);
          v_cod_persona := lf_obt_per_banco(v_cod_banco);
          lp_obt_dat_persona(NULL, v_cod_persona, rp_stdet.tip_doc_beneficiario, rp_stdet.nro_doc_beneficiario);
          pre_obt_pai_iso(v_cod_persona, NULL, NULL, rp_stdet.des_ciu_iso_destino, rp_stdet.cod_pai_iso_destino);
          lp_obt_cod_swift(v_cod_banco, NULL, rp_stdet.cod_swi_bco_beneficiario);
          rp_stdet.nro_cta_beneficiario := nvl(j.nro_cuenta, 0);
        END IF;
      END LOOP;
      v_nro_registro        := v_nro_registro + 1;
      rp_stdet.nro_registro := v_nro_registro;
      lp_ins_transferencias_det(rp_stdet);
    END LOOP;
  END;

  PROCEDURE lp_gen_deb_cre_gui IS
    CURSOR c_transferencias IS
      SELECT fecha,
             fec_valor,
             monto,
             nro_cuenta,
             cod_moneda,
             cod_ofi_origen,
             concepto,
             cod_transaccion,
             nro_documento,
             cod_persona,
             cod_modulo,
             cod_modalidad
      FROM ge_movimientos g
      WHERE g.cod_mad_padre = 455
      AND g.cod_tra_padre = 303
      AND g.reversado = 'N'
      AND g.estado = 'N'
      AND g.cod_transaccion IN (4711 /*enviadas*/, 4712 /*recibidas*/)
      AND nvl(pag_gen.fu_con_mon_a_moneda(g.cod_moneda, v_cod_mon_local, g.monto, NULL, v_fec_actual, NULL), 0) >
            v_mto_minimo
      AND g.fecha = v_fec_actual
      AND NOT EXISTS (SELECT 1
             FROM ge_snp_transferencias
             WHERE nro_referencia = g.nro_documento
             AND fec_valor = g.fecha);
  BEGIN
    FOR i IN c_transferencias
    LOOP
      rp_stdet.fecha          := v_fec_actual;
      rp_stdet.tip_movimiento := 3;
      rp_stdet.tip_operacion  := 'L';
      rp_stdet.cod_oficina    := i.cod_ofi_origen;
      rp_stdet.nro_operacion  := i.nro_documento;
      rp_stdet.cod_mon_iso    := i.cod_moneda;
      rp_stdet.fec_operacion  := i.fecha;
      rp_stdet.cod_modulo     := i.cod_modulo;
      rp_stdet.cod_modalidad  := i.cod_modalidad;
      lp_obt_dat_persona(i.nro_cuenta, v_cod_persona, rp_stdet.tip_doc_ordenante, rp_stdet.nro_doc_ordenante);
      IF i.cod_transaccion = 4711 THEN
        rp_stdet.nro_cta_ordenante    := nvl(i.nro_cuenta, 0);
        rp_stdet.nro_cta_beneficiario := 0;
      ELSE
        rp_stdet.nro_cta_ordenante    := 0;
        rp_stdet.nro_cta_beneficiario := nvl(i.nro_cuenta, 0);
      END IF;
      rp_stdet.monto          := i.monto;
      rp_stdet.val_conversion := fug_obt_cotizacion(i.cod_moneda, i.fec_valor);
      lp_obt_cod_swift(NULL, v_cod_entidad, rp_stdet.cod_swi_bco_intermediario);
      pre_obt_pai_iso(v_cod_per_entidad, NULL, NULL, rp_stdet.des_ciu_iso_origen, rp_stdet.cod_pai_iso_origen);
      rp_stdet.cod_swi_bco_beneficiario := rp_stdet.cod_swi_bco_intermediario;
      rp_stdet.des_ciu_iso_destino      := rp_stdet.des_ciu_iso_origen;
      rp_stdet.cod_pai_iso_destino      := rp_stdet.cod_pai_iso_origen;
      v_val_parametro                   := fug_obt_pardinamico('SIB_TRA_OPE_GUI');
      rp_stdet.tip_fondo                := pae_uti.fu_obt_valor(v_val_parametro, 1);
      --BSEVOCORE-904 Sí el tipo de documento del ordenante es RUC cambia el tipo de fondo a 2  Privado – Empresa
      IF rp_stdet.tip_doc_ordenante = 'RUC' THEN
        rp_stdet.tip_fondo := 2;
      END IF;
      --FIN BSEVOCORE-904
      rp_stdet.tip_motivo             := pae_uti.fu_obt_valor(v_val_parametro, 2);
      rp_stdet.tip_financiacion       := pae_uti.fu_obt_valor(v_val_parametro, 3);
      rp_stdet.tip_doc_transportadora := NULL;
      rp_stdet.nro_doc_transportadora := NULL;
      rp_stdet.tip_doc_beneficiario   := rp_stdet.tip_doc_ordenante;
      rp_stdet.nro_doc_beneficiario   := rp_stdet.nro_doc_ordenante;
      v_nro_registro                  := v_nro_registro + 1;
      rp_stdet.nro_registro           := v_nro_registro;
      lp_ins_transferencias_det(rp_stdet);
    END LOOP;
  END;

  PROCEDURE lp_gen_emi_rec_gui IS
    CURSOR c_movimientos IS
      SELECT DISTINCT g.fecha, g.hora, g.cod_usuario
      FROM ge_movimientos g
      WHERE g.cod_mad_padre = 455
      AND g.cod_tra_padre = 303
      AND g.cod_modalidad = 455
      AND g.reversado = 'N'
      AND g.estado = 'N'
      AND (upper(g.concepto) NOT LIKE upper('%combinada%') AND
            upper(g.concepto) NOT LIKE upper('%Transf.CComb.Nro%') AND
            upper(g.concepto) NOT LIKE upper('%Transf.a la Cta%'))
      AND g.cod_transaccion IN (190 /*debito*/, 196 /*credito*/)
      AND g.fecha = v_fec_actual
      AND nvl(pag_gen.fu_con_mon_a_moneda(g.cod_moneda, v_cod_mon_local, g.monto, NULL, v_fec_actual, NULL), 0) >
            v_mto_minimo
      AND NOT EXISTS (SELECT 1
             FROM ge_snp_transferencias
             WHERE nro_referencia = g.nro_documento
             AND fec_valor = g.fecha);
    CURSOR c_cuentas IS
      SELECT fecha,
             hora,
             cod_usuario,
             nro_secuencia,
             fec_valor,
             monto,
             nro_cuenta,
             cod_moneda,
             cod_modalidad,
             cod_oficina,
             cod_ofi_origen,
             cod_tra_padre,
             cod_mod_padre,
             cod_mad_padre,
             cod_transaccion,
             nro_documento,
             nro_documento2,
             nro_documento3,
             nro_documento4,
             concepto,
             cod_modulo
      FROM ge_movimientos
      WHERE fecha = v_fecha
      AND hora = v_hora
      AND cod_usuario = v_cod_usuario
      AND cod_tra_padre = 303
      AND nro_secuencia < 900;
  BEGIN
    FOR i IN c_movimientos
    LOOP
      v_fecha                 := i.fecha;
      v_hora                  := i.hora;
      v_cod_usuario           := i.cod_usuario;
      rp_stdet.tip_movimiento := 3;
      rp_stdet.tip_operacion  := 'L';
      rp_stdet.fecha          := v_fec_actual;
      FOR j IN c_cuentas
      LOOP
        IF nvl(j.cod_transaccion, 0) IN (190, 503) THEN
          -- débito/origen
          rp_stdet.cod_oficina    := j.cod_ofi_origen;
          rp_stdet.cod_mon_iso    := j.cod_moneda;
          rp_stdet.fec_operacion  := j.fecha;
          rp_stdet.nro_operacion  := j.nro_documento;
          rp_stdet.monto          := j.monto;
          rp_stdet.cod_modulo     := j.cod_modulo;
          rp_stdet.cod_modalidad  := j.cod_modalidad;
          rp_stdet.val_conversion := fug_obt_cotizacion(j.cod_moneda, j.fecha);
          lp_obt_dat_persona(j.nro_cuenta, v_cod_per_ordenante, rp_stdet.tip_doc_ordenante, rp_stdet.nro_doc_ordenante);
          pre_obt_pai_iso(v_cod_per_ordenante, NULL, NULL, rp_stdet.des_ciu_iso_origen, rp_stdet.cod_pai_iso_origen);
          IF j.cod_transaccion = 190 THEN
            rp_stdet.nro_cta_ordenante    := nvl(j.nro_cuenta, 0);
            rp_stdet.nro_cta_beneficiario := 0;
          ELSE
            rp_stdet.nro_cta_ordenante    := 0;
            rp_stdet.nro_cta_beneficiario := nvl(j.nro_cuenta, 0);
          END IF;
          lp_obt_cod_swift(NULL, v_cod_entidad, rp_stdet.cod_swi_bco_intermediario);
          rp_stdet.cod_swi_bco_beneficiario := rp_stdet.cod_swi_bco_intermediario;
          v_concepto                        := lf_obt_dat_concepto(j.concepto);
          lp_obt_dat_referencia(v_concepto, rp_stdet.tip_fondo, rp_stdet.tip_motivo, rp_stdet.tip_financiacion);
          rp_stdet.tip_doc_transportadora := NULL;
          rp_stdet.nro_doc_transportadora := NULL;
          rp_stdet.autorizado             := fue_per_dat_adicional(v_cod_per_ordenante, 'TRA_AUT_ENV_DATOS');
          --BSEVOCORE-904 Sí el tipo de documento del ordenante es RUC cambia el tipo de fondo a 2  Privado – Empresa
          v_val_parametro    := fug_obt_pardinamico('SIB_TRA_OPE_GUI');
          rp_stdet.tip_fondo := pae_uti.fu_obt_valor(v_val_parametro, 1);
          IF rp_stdet.tip_doc_ordenante = 'RUC' THEN
            rp_stdet.tip_fondo := 2;
          END IF;
          rp_stdet.tip_motivo       := pae_uti.fu_obt_valor(v_val_parametro, 2);
          rp_stdet.tip_financiacion := pae_uti.fu_obt_valor(v_val_parametro, 3);
          --FIN BSEVOCORE-904
        ELSIF nvl(j.cod_transaccion, 0) IN (196, 602) THEN
          -- destino/credito
          rp_stdet.nro_operacion := j.nro_documento;
          lp_obt_dat_persona(j.nro_cuenta, v_cod_per_entidad, rp_stdet.tip_doc_beneficiario, rp_stdet.nro_doc_beneficiario);
          pre_obt_pai_iso(v_cod_per_entidad, NULL, NULL, rp_stdet.des_ciu_iso_destino, rp_stdet.cod_pai_iso_destino);
          --BSEVOCORE-904 Sí el tipo de documento del ordenante es RUC cambia el tipo de fondo a 2  Privado – Empresa
          v_val_parametro    := fug_obt_pardinamico('SIB_TRA_OPE_GUI');
          rp_stdet.tip_fondo := pae_uti.fu_obt_valor(v_val_parametro, 1);
          IF rp_stdet.tip_doc_ordenante = 'RUC' THEN
            rp_stdet.tip_fondo := 2;
          END IF;
          rp_stdet.tip_motivo       := pae_uti.fu_obt_valor(v_val_parametro, 2);
          rp_stdet.tip_financiacion := pae_uti.fu_obt_valor(v_val_parametro, 3);
          --FIN BSEVOCORE-904
        END IF;
      END LOOP;
      v_nro_registro        := v_nro_registro + 1;
      rp_stdet.nro_registro := v_nro_registro;
      lp_ins_transferencias_det(rp_stdet);
    END LOOP;
  END;

  PROCEDURE lp_tra_ord_pag_internas IS
    v_cod_ciudad ba_ciudades.cod_ciudad%TYPE;
    v_cod_pais   ba_paises.cod_pais%TYPE;
    CURSOR c_pago IS
      SELECT p.nro_orden,
             p.tip_comprobante,
             p.nro_cta_credito,
             p.nro_doc_beneficiario,
             p.cod_moneda,
             p.monto,
             p.fec_pago,
             p.cod_oficina,
             p.nro_cta_debito,
             p.cod_tip_doc_beneficiario
      FROM ge_pag_proveedores p
      WHERE p.cod_ente = 1107
      AND p.estado = 'N'
      AND p.fec_pago = v_fec_actual;
  BEGIN
    v_cod_persona := NULL;
    FOR i IN c_pago
    LOOP
      rp_stdet.tip_movimiento    := 3;
      rp_stdet.tip_operacion     := 'L';
      rp_stdet.fecha             := v_fec_actual;
      rp_stdet.cod_modulo        := 28;
      rp_stdet.cod_modalidad     := 281;
      rp_stdet.cod_oficina       := i.cod_oficina;
      rp_stdet.nro_operacion     := i.nro_orden;
      rp_stdet.cod_mon_iso       := i.cod_moneda;
      rp_stdet.fec_operacion     := i.fec_pago;
      rp_stdet.monto             := i.monto;
      rp_stdet.nro_cta_ordenante := i.nro_cta_debito;
      rp_stdet.val_conversion    := fug_obt_cotizacion(i.cod_moneda, i.fec_pago);
      lp_obt_dat_persona(i.nro_cta_debito, v_cod_persona, rp_stdet.tip_doc_ordenante, rp_stdet.nro_doc_ordenante);
      lp_obt_cod_swift(NULL, v_cod_entidad, rp_stdet.cod_swi_bco_intermediario);
      rp_stdet.cod_swi_bco_beneficiario := rp_stdet.cod_swi_bco_intermediario;
      pre_obt_pai_iso(v_cod_persona, NULL, NULL, rp_stdet.des_ciu_iso_origen, rp_stdet.cod_pai_iso_origen);
      v_val_parametro                 := fug_obt_pardinamico('SIB_TRA_ORD_INTERNAS');
      rp_stdet.tip_fondo              := pae_uti.fu_obt_valor(v_val_parametro, 1);
      rp_stdet.tip_motivo             := pae_uti.fu_obt_valor(v_val_parametro, 2);
      rp_stdet.tip_financiacion       := pae_uti.fu_obt_valor(v_val_parametro, 3);
      rp_stdet.tip_doc_transportadora := NULL;
      rp_stdet.nro_doc_transportadora := NULL;
      rp_stdet.nro_cta_beneficiario   := 0;
      rp_stdet.tip_doc_beneficiario   := fue_obt_tip_doc_abreviatura(nvl(i.cod_tip_doc_beneficiario, 1));
      rp_stdet.nro_doc_beneficiario   := i.nro_doc_beneficiario;
      lp_obt_dat_oficina(i.cod_oficina, v_cod_ciudad, v_cod_pais);
      pre_obt_pai_iso(NULL, v_cod_pais, v_cod_ciudad, rp_stdet.des_ciu_iso_destino, rp_stdet.cod_pai_iso_destino);
      v_nro_registro        := v_nro_registro + 1;
      rp_stdet.nro_registro := v_nro_registro;
      lp_ins_transferencias_det(rp_stdet);
    END LOOP;
  END;

  PROCEDURE lp_tra_ord_pag_bts IS
    v_cod_ciudad ba_ciudades.cod_ciudad%TYPE;
    v_cod_pais   ba_paises.cod_pais%TYPE;
    CURSOR c_pago IS
      SELECT p.nro_orden,
             p.tip_comprobante,
             p.nro_cta_credito,
             p.nro_doc_beneficiario,
             p.cod_moneda,
             p.monto,
             p.fec_pago,
             p.cod_oficina,
             p.nro_cta_debito,
             p.cod_tip_doc_beneficiario
      FROM ge_pag_proveedores p
      WHERE p.cod_ente = 1091
      AND p.estado = 'N'
      AND p.fec_pago = v_fec_actual;
  BEGIN
    v_cod_per_ordenante := fue_obt_per_ente(1091);
    FOR i IN c_pago
    LOOP
      rp_stdet.tip_movimiento    := 1;
      rp_stdet.tip_operacion     := 'L';
      rp_stdet.fecha             := v_fec_actual;
      rp_stdet.cod_modulo        := 28;
      rp_stdet.cod_modalidad     := 281;
      rp_stdet.cod_oficina       := i.cod_oficina;
      rp_stdet.nro_operacion     := i.nro_orden;
      rp_stdet.cod_mon_iso       := i.cod_moneda;
      rp_stdet.fec_operacion     := i.fec_pago;
      rp_stdet.monto             := i.monto;
      rp_stdet.nro_cta_ordenante := nvl(fug_obt_parentes(1091, 'TRA_NRO_CTA_ORDENANTE'), 0);
      rp_stdet.val_conversion    := fug_obt_cotizacion(i.cod_moneda, i.fec_pago);
      lp_obt_dat_persona(NULL, v_cod_per_ordenante, rp_stdet.tip_doc_ordenante, rp_stdet.nro_doc_ordenante);
      rp_stdet.cod_swi_bco_intermediario := fug_obt_parentes(1091, 'TRA_SWI_INTERMEDIARIO');
      pre_obt_pai_iso(v_cod_per_ordenante, NULL, NULL, rp_stdet.des_ciu_iso_origen, rp_stdet.cod_pai_iso_origen);
      lp_obt_cod_swift(NULL, v_cod_entidad, rp_stdet.cod_swi_bco_beneficiario);
      v_val_parametro                 := fug_obt_pardinamico('SIB_TRA_ORD_INTERNAS');
      rp_stdet.tip_fondo              := pae_uti.fu_obt_valor(v_val_parametro, 1);
      rp_stdet.tip_motivo             := pae_uti.fu_obt_valor(v_val_parametro, 2);
      rp_stdet.tip_financiacion       := pae_uti.fu_obt_valor(v_val_parametro, 3);
      rp_stdet.tip_doc_transportadora := NULL;
      rp_stdet.nro_doc_transportadora := NULL;
      rp_stdet.nro_cta_beneficiario   := 0;
      rp_stdet.tip_doc_beneficiario   := fue_obt_tip_doc_abreviatura(nvl(i.cod_tip_doc_beneficiario, 1));
      rp_stdet.nro_doc_beneficiario   := i.nro_doc_beneficiario;
      lp_obt_dat_oficina(i.cod_oficina, v_cod_ciudad, v_cod_pais);
      pre_obt_pai_iso(NULL, v_cod_pais, v_cod_ciudad, rp_stdet.des_ciu_iso_destino, rp_stdet.cod_pai_iso_destino);
      v_nro_registro        := v_nro_registro + 1;
      rp_stdet.nro_registro := v_nro_registro;
      lp_ins_transferencias_det(rp_stdet);
    END LOOP;
  END;

  PROCEDURE lp_gen_tra_atm IS
    v_monto ge_movimientos.monto%TYPE;
    CURSOR c_movimientos IS
      SELECT DISTINCT g.fecha, g.hora, g.cod_usuario, g.monto
      FROM ge_movimientos g
      WHERE g.cod_tra_padre = 228
      AND g.reversado = 'N'
      AND g.estado = 'N'
      AND g.cod_transaccion IN (503, 602)
      AND (upper(g.concepto) NOT LIKE upper('%combinada%') AND
            upper(g.concepto) NOT LIKE upper('%Transf.CComb.Nro%') AND
            upper(g.concepto) NOT LIKE upper('%Transf.a la Cta%'))
      AND g.fecha = v_fec_actual
      AND g.nro_secuencia < 900
      AND nvl(pag_gen.fu_con_mon_a_moneda(g.cod_moneda, v_cod_mon_local, g.monto, NULL, v_fec_actual, NULL), 0) >
            v_mto_minimo
      AND NOT EXISTS (SELECT hora
             FROM ge_movimientos
             WHERE cod_tra_padre = 228
             AND reversado = 'N'
             AND estado = 'N'
             AND cod_transaccion IN (503, 602)
             AND fecha = g.fecha
             AND hora <> g.hora
             AND g.nro_documento = nro_documento
             AND monto < 0
             AND nro_secuencia < 900
             AND abs(monto) = g.monto)
      AND NOT EXISTS (SELECT hora
             FROM ge_movimientos
             WHERE cod_tra_padre = 228
             AND reversado = 'N'
             AND estado = 'N'
             AND cod_transaccion IN (503, 602)
             AND cod_modalidad = 45
             AND nro_secuencia < 900
             AND nvl(pag_gen.fu_con_mon_a_moneda(cod_moneda, v_cod_mon_local, monto, NULL, v_fec_actual, NULL), 0) >
                   v_mto_minimo
             AND fecha = g.fecha
             AND hora = g.hora
             AND g.nro_documento = nro_documento);
    CURSOR c_cuentas IS
      SELECT fecha,
             hora,
             cod_usuario,
             nro_secuencia,
             fec_valor,
             monto,
             nro_cuenta,
             cod_moneda,
             cod_modalidad,
             cod_oficina,
             cod_ofi_origen,
             cod_tra_padre,
             cod_mod_padre,
             cod_mad_padre,
             cod_transaccion,
             nro_documento,
             nro_documento2,
             nro_documento3,
             nro_documento4,
             referencia,
             cod_modulo
      FROM ge_movimientos
      WHERE fecha = v_fecha
      AND hora = v_hora
      AND cod_usuario = v_cod_usuario
      AND cod_tra_padre = 228
      AND nro_secuencia < 900
      AND monto = v_monto;
  BEGIN
    FOR i IN c_movimientos
    LOOP
      v_fecha                 := i.fecha;
      v_hora                  := i.hora;
      v_cod_usuario           := i.cod_usuario;
      v_monto                 := i.monto;
      rp_stdet.tip_movimiento := 3;
      rp_stdet.tip_operacion  := 'L';
      rp_stdet.fecha          := v_fec_actual;
      v_cod_per_ordenante     := NULL;
      v_cod_per_beneficiario  := NULL;
      FOR j IN c_cuentas
      LOOP
        IF nvl(j.cod_transaccion, 0) = 503 THEN
          -- débito/origen
          rp_stdet.cod_oficina   := j.cod_ofi_origen;
          rp_stdet.cod_mon_iso   := j.cod_moneda;
          rp_stdet.fec_operacion := j.fecha;
          rp_stdet.cod_modulo    := j.cod_modulo;
          rp_stdet.cod_modalidad := j.cod_modalidad;
          IF j.cod_modalidad = 42 THEN
            lp_obt_cod_swift(lf_obt_cod_banco(j.nro_cuenta), NULL, rp_stdet.cod_swi_bco_intermediario);
          ELSE
            lp_obt_cod_swift(NULL, v_cod_entidad, rp_stdet.cod_swi_bco_intermediario);
          END IF;
          lp_obt_cod_swift(NULL, v_cod_entidad, rp_stdet.cod_swi_bco_beneficiario);
          rp_stdet.nro_operacion := j.nro_documento;
          lp_obt_dat_persona(j.nro_cuenta, v_cod_per_ordenante, rp_stdet.tip_doc_ordenante, rp_stdet.nro_doc_ordenante);
          pre_obt_pai_iso(v_cod_per_ordenante, NULL, NULL, rp_stdet.des_ciu_iso_origen, rp_stdet.cod_pai_iso_origen);
          rp_stdet.nro_cta_ordenante := nvl(j.nro_cuenta, 0);
          rp_stdet.monto             := j.monto;
          rp_stdet.val_conversion    := fug_obt_cotizacion(j.cod_moneda, j.fecha);
          v_val_parametro            := fug_obt_pardinamico('SIB_TRA_DAT_ATM');
          rp_stdet.tip_fondo         := pae_uti.fu_obt_valor(v_val_parametro, 1);
          --BSEVOCORE-904 por defecto del parametro viene 1, si es persona juridica debe ser 2
          IF rp_stdet.tip_doc_ordenante = 'RUC' THEN
            --RUC
            rp_stdet.tip_fondo := 2;
          END IF;
          --Fin BSEVOCORE-904
          rp_stdet.tip_motivo             := pae_uti.fu_obt_valor(v_val_parametro, 2);
          rp_stdet.tip_financiacion       := pae_uti.fu_obt_valor(v_val_parametro, 3);
          rp_stdet.tip_doc_transportadora := NULL;
          rp_stdet.nro_doc_transportadora := NULL;
          rp_stdet.autorizado             := fue_per_dat_adicional(v_cod_per_ordenante, 'TRA_AUT_ENV_DATOS');
        ELSIF nvl(j.cod_transaccion, 0) = 602 THEN
          -- destino/credito
          rp_stdet.nro_operacion := j.nro_documento;
          IF j.cod_modalidad = 42 THEN
            lp_obt_cod_swift(lf_obt_cod_banco(j.nro_cuenta), NULL, rp_stdet.cod_swi_bco_beneficiario);
          ELSE
            lp_obt_cod_swift(NULL, v_cod_entidad, rp_stdet.cod_swi_bco_beneficiario);
          END IF;
          lp_obt_dat_persona(j.nro_cuenta, v_cod_per_beneficiario, rp_stdet.tip_doc_beneficiario, rp_stdet.nro_doc_beneficiario);
          pre_obt_pai_iso(v_cod_per_beneficiario, NULL, NULL, rp_stdet.des_ciu_iso_destino, rp_stdet.cod_pai_iso_destino);
          rp_stdet.nro_cta_beneficiario := nvl(j.nro_cuenta, 0);
          --BSEVOCORE-904 Sí el tipo de documento del ordenante es RUC cambia el tipo de fondo a 2  Privado – Empresa
          v_val_parametro    := fug_obt_pardinamico('SIB_TRA_DAT_ATM');
          rp_stdet.tip_fondo := pae_uti.fu_obt_valor(v_val_parametro, 1);
          IF rp_stdet.tip_doc_ordenante = 'RUC' THEN
            --RUC
            rp_stdet.tip_fondo := 2;
          END IF;
          rp_stdet.tip_motivo       := pae_uti.fu_obt_valor(v_val_parametro, 2);
          rp_stdet.tip_financiacion := pae_uti.fu_obt_valor(v_val_parametro, 3);
          --Fin BSEVOCORE-904
        END IF;
      END LOOP;
      v_nro_registro        := v_nro_registro + 1;
      rp_stdet.nro_registro := v_nro_registro;
      lp_ins_transferencias_det(rp_stdet);
    END LOOP;
  END;

  PROCEDURE lp_gen_ext_atm IS
    CURSOR c_movimientos IS
      SELECT DISTINCT g.fecha,
                      g.hora,
                      g.cod_usuario,
                      g.fec_valor,
                      g.monto,
                      g.nro_cuenta,
                      g.cod_moneda,
                      g.cod_modalidad,
                      g.cod_oficina,
                      g.cod_ofi_origen,
                      g.cod_tra_padre,
                      g.cod_mod_padre,
                      g.cod_mad_padre,
                      g.cod_transaccion,
                      g.nro_documento,
                      g.nro_documento2,
                      g.nro_documento3,
                      g.nro_documento4,
                      g.referencia,
                      g.cod_modulo
      FROM ge_movimientos g
      WHERE g.cod_tra_padre = 382
      AND g.reversado = 'N'
      AND g.estado = 'N'
      AND monto > 0
      AND g.fecha = v_fec_actual
      AND NOT EXISTS (SELECT hora
             FROM ge_movimientos
             WHERE cod_tra_padre = 382
             AND reversado = 'N'
             AND estado = 'N'
             AND fecha = g.fecha
             AND hora <> g.hora
             AND g.nro_documento3 = nro_documento3
             AND monto < 0
             AND abs(monto) = g.monto);
  BEGIN
    FOR i IN c_movimientos
    LOOP
      rp_stdet.fecha          := v_fec_actual;
      rp_stdet.tip_movimiento := 3;
      rp_stdet.tip_operacion  := 'L';
      rp_stdet.cod_oficina    := i.cod_ofi_origen;
      rp_stdet.nro_operacion  := i.nro_documento;
      rp_stdet.cod_mon_iso    := i.cod_moneda;
      rp_stdet.fec_operacion  := i.fecha;
      rp_stdet.cod_modulo     := i.cod_modulo;
      rp_stdet.cod_modalidad  := i.cod_modalidad;
      lp_obt_dat_persona(i.nro_cuenta, v_cod_persona, rp_stdet.tip_doc_ordenante, rp_stdet.nro_doc_ordenante);
      rp_stdet.nro_cta_ordenante    := nvl(i.nro_cuenta, 0);
      rp_stdet.nro_cta_beneficiario := 0;
      rp_stdet.monto                := i.monto;
      rp_stdet.val_conversion       := fug_obt_cotizacion(i.cod_moneda, i.fec_valor);
      lp_obt_cod_swift(NULL, v_cod_entidad, rp_stdet.cod_swi_bco_intermediario);
      lp_obt_dat_persona(i.nro_cuenta, v_cod_persona, rp_stdet.tip_doc_ordenante, rp_stdet.nro_doc_ordenante);
      pre_obt_pai_iso(v_cod_persona, NULL, NULL, rp_stdet.des_ciu_iso_origen, rp_stdet.cod_pai_iso_origen);
      rp_stdet.cod_swi_bco_beneficiario := rp_stdet.cod_swi_bco_intermediario;
      pre_obt_pai_iso(v_cod_per_entidad, NULL, NULL, rp_stdet.des_ciu_iso_destino, rp_stdet.cod_pai_iso_destino);
      v_val_parametro                 := fug_obt_pardinamico('SIB_TRA_DAT_ATM');
      rp_stdet.tip_fondo              := pae_uti.fu_obt_valor(v_val_parametro, 1);
      rp_stdet.tip_motivo             := pae_uti.fu_obt_valor(v_val_parametro, 2);
      rp_stdet.tip_financiacion       := pae_uti.fu_obt_valor(v_val_parametro, 3);
      rp_stdet.tip_doc_transportadora := NULL;
      rp_stdet.nro_doc_transportadora := NULL;
      lp_obt_dat_persona(NULL, v_cod_per_entidad, rp_stdet.tip_doc_beneficiario, rp_stdet.nro_doc_beneficiario);
      v_nro_registro        := v_nro_registro + 1;
      rp_stdet.nro_registro := v_nro_registro;
      lp_ins_transferencias_det(rp_stdet);
    END LOOP;
  END;

  PROCEDURE pr_gen_transferencias IS
  BEGIN
    pag_cal.pr_obt_dat_calendar(6);
    v_fec_actual := pag_cal.fu_obt_fec_actual(6);
    DELETE sb_transferencias_det
    WHERE fecha = v_fec_actual;
    DELETE sb_transferencias
    WHERE fec_periodo = v_fec_actual;
    COMMIT;
    v_nro_registro := 0;
    BEGIN
      SELECT nvl(sal_min_vigente, 0)
      INTO v_sal_minimo
      FROM pr_parametros
      WHERE rownum = 1;
    EXCEPTION
      WHEN OTHERS THEN
        NULL;
    END;
    v_mto_minimo := v_sal_minimo * NVL(v_can_salarios, 1);
    ---- Genero los datos de los detalles.
    -- Emitidas
    v_lugar := 'lp_tra_emitidas';
    lp_tra_emitidas;
    v_lugar := 'lp_tra_emi_corresponsales';
    lp_tra_emi_corresponsales;
    v_lugar := 'lp_gen_tra_importaciones';
    lp_gen_tra_importaciones;
    v_lugar := 'lp_gen_tra_cob_importacion';
    lp_gen_tra_cob_importacion;
    -- Recibidas
    v_lugar := 'lp_gen_tra_recibidas';
    lp_gen_tra_recibidas;
    v_lugar := 'lp_tra_rec_corresponsales';
    lp_tra_rec_corresponsales;
    v_lugar := 'lp_gen_tra_exportaciones';
    lp_gen_tra_exportaciones;
    v_lugar := 'lp_gen_tra_cob_exportacion';
    lp_gen_tra_cob_exportacion;
    -- Exportación de divisas
    v_lugar := 'lp_gen_tra_exp_divisas';
    lp_gen_tra_exp_divisas;
    -- Transferencias en el Exterior
    v_lugar := 'lp_tra_ext_corresponsales';
    lp_tra_ext_corresponsales;
    -- Transferencias Locales Interdepartamentales
    v_lugar := 'lp_gen_tra_cuentas';
    lp_gen_tra_cuentas;
    v_lugar := 'lp_gen_tra_com_divisas';
    lp_gen_tra_com_divisas;
    v_lugar := 'lp_gen_tra_rec_sipap';
    lp_gen_tra_rec_sipap;
    v_lugar := 'lp_gen_tra_env_sipap';
    lp_gen_tra_env_sipap;
    IF v_cod_entidad NOT IN (1028, 2079) THEN
      v_lugar := 'lp_gen_deb_cre_gui';
      lp_gen_deb_cre_gui;
      v_lugar := 'lp_gen_emi_rec_gui';
      lp_gen_emi_rec_gui;
    END IF;
    v_lugar := 'lp_tra_ord_pag_internas';
    lp_tra_ord_pag_internas;
  --  lp_tra_ord_pag_bts;
    v_lugar := 'lp_gen_tra_atm';
    lp_gen_tra_atm;
    v_lugar := 'lp_gen_tra_internas';
    lp_gen_tra_internas;
    v_lugar := 'lp_act_tot_registro';
    lp_act_tot_registro(v_fec_actual);
    exception
    when others then
     raise_application_error( -20000, 'Error en '||v_lugar||' '||sqlerrm);
  END;
END;
