create or replace PACKAGE BODY      IT.pas_cri IS

   -- Author  : RBATTAGLIA
   -- Created : 23/01/2013 01:38:40 p.m.
   -- Purpose : Nuevo Formato de Envio de CRC
   v_fec_actual             ge_calendarios.fec_actual%TYPE;
   v_fec_proxima            ge_calendarios.fec_actual%TYPE;
   v_fec_inicio             ge_calendarios.fec_actual%TYPE;
   v_fec_fin                ge_calendarios.fec_actual%TYPE;
   v_fec_anterior           ge_calendarios.fec_anterior%TYPE;
   v_fec_ult_mes            ge_calendarios.fec_anterior%TYPE;
   v_fec_ant_categoria      ge_calendarios.fec_anterior%TYPE;
   v_fec_ini_ant            ge_calendarios.fec_actual%TYPE;
   v_fec_fin_ant            ge_calendarios.fec_actual%TYPE;
   v_cod_entidad            ge_par_generales.cod_entidad%TYPE := fu_obt_cod_entidad;
   v_fec_ini_tarjeta        ge_calendarios.fec_actual%TYPE;
   v_fec_fin_tarjeta        ge_calendarios.fec_actual%TYPE;
   v_cod_per_entidad        ge_par_generales.cod_persona%TYPE := fug_obt_per_entidad;
   v_cod_per_bco_central    ge_bancos.cod_persona%TYPE := fug_obt_per_bco_central;
   v_fec_imp_cta_lib        ge_calendarios.fec_actual%TYPE := to_date(fug_obt_pardinamico('SIB_CRC_FEC_CTA_LIB'),'dd/mm/yyyy');
   v_crc_can_dia_incobrable ge_par_dinamicos.val_parametro%TYPE := fug_obt_pardinamico('CRC_CAN_DIA_INCOBRABLE');
   v_inc_emisores           ge_par_dinamicos.val_parametro%TYPE := fug_obt_pardinamico('SIB_CRC_INC_CLA_EMISORES');
   v_inc_conyuges           ge_par_dinamicos.val_parametro%TYPE := fug_obt_pardinamico('CRC_DAT_CONYUGES');
   v_cod_mon_local          ge_par_generales.cod_mon_local%TYPE := pag_gen.fu_obt_mon_local;
   v_inc_ope_entidad        ge_par_dinamicos.val_parametro%TYPE := fug_obt_pardinamico('SIB_CRC_INC_OPE_ENTIDAD');
   v_tip_mod_cav_cancela    ge_par_dinamicos.val_parametro%TYPE := fug_obt_pardinamico('TIP_MOD_CAV_CANCELA');
   v_tip_ope_cda_cancela    ge_par_dinamicos.val_parametro%TYPE := fug_obt_pardinamico('TIP_OPE_CDA_CANCELA');
   v_redondeo               ge_par_dinamicos.val_parametro%TYPE := nvl(fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                                                                                           NULL,
                                                                                           NULL,
                                                                                           v_cod_mon_local,
                                                                                           NULL),
                                                                       0);
   v_tip_ope_cup_ven        ge_par_dinamicos.val_parametro%TYPE := fug_obt_pardinamico('SIB_CRC_TIP_OPE_CUP_VEN');
   v_inc_cup_cda            ge_par_dinamicos.val_parametro%TYPE := fug_obt_pardinamico('SIB_INC_CUP_CDA_OPERACIONES');
   v_ope_sob_linea1         ge_par_dinamicos.val_parametro%TYPE := fug_obt_pardinamico('TIP_OPE_SOB_LINEA1');
   v_ope_sob_linea2         ge_par_dinamicos.val_parametro%TYPE := fug_obt_pardinamico('TIP_OPE_SOB_LINEA2');
   v_inc_cla_conyuges       ge_par_dinamicos.val_parametro%TYPE := fug_obt_pardinamico('SIB_INC_CLA_CONYUGES');
   v_act_personas_ref       ge_par_dinamicos.val_parametro%TYPE := fug_obt_pardinamico('SIB_CRC_USA_PERSONAS_REF');
   v_inc_cta_bancarias      ge_par_dinamicos.val_parametro%TYPE := fug_obt_pardinamico('SIB_CRC_INC_CTA_BANCARIAS');
   v_cod_rub_sal_capital_cc ge_par_dinamicos.val_parametro%TYPE := fug_obt_pardinamico('COD_RUBRO_CAPITAL_CC');
   v_mad_aho_plazo          ge_par_dinamicos.val_parametro%TYPE := fug_obt_pardinamico('MAD_AHO_PLAZO');
   v_cotizacion             ge_cotizaciones.val_conversion%TYPE;
   v_nro_registro           NUMBER(18) := 0; -- contador de numeros de registros de vinculos
   v_nro_reg_vin            NUMBER(18) := 0;
   v_existe                 VARCHAR2(1);
   v_mensaje                VARCHAR2(10000) := NULL;
   v_tip_saldo           cb_sal_inventarios.tip_saldo%TYPE := 'C';
   v_vin_cod_persona        sb_crc_vinculos_det.cod_persona%TYPE;
   v_inf_dia_persona     varchar2(1) := nvl(fug_obt_pardinamico('SIB_CRC_SAL_DIA_PERSONA'), 'N');
   TYPE  cursorCliOp_type IS TABLE OF ge_clientes_nov%ROWTYPE;
   TYPE  rp_slcrc_type    IS TABLE OF sb_log_crc%ROWTYPE;
   v_cta_credito                  AH_CTA_CERTIFICADOS.NRO_CTA_CREDITO%TYPE;
   v_tas_minima                   GE_TAS_FECHAS.VAL_TASA%TYPE;

   PROCEDURE lp_act_tot_registro(p_fec_periodo    sb_crc_operaciones.fec_periodo%TYPE,
                                 p_nom_tabla      IN VARCHAR2,
                                 p_nom_referencia sb_crc_garantias_det.nom_referencia%TYPE default null) IS
      v_tot_registro NUMBER(21);
   BEGIN
      IF p_nom_tabla = 'SB_CRC_OPERACIONES' THEN
         --1.- Tabla de Operaciones
         SELECT COUNT(*)
           INTO v_tot_registro
           FROM sb_crc_operaciones_det
          WHERE fecha = p_fec_periodo;
         -- Actualizo la tabla de operaciones
         UPDATE sb_crc_operaciones
            SET tot_registro = nvl(v_tot_registro, 0)
          WHERE fec_periodo = p_fec_periodo;
         IF SQL%NOTFOUND THEN
            INSERT INTO sb_crc_operaciones
               (nom_referencia, fec_periodo, cod_entidad, tot_registro)
            VALUES
               ('OPERACION', p_fec_periodo, v_cod_entidad, nvl(v_tot_registro, 0));
         END IF;
         --2.- Tabla de Vinculos
         SELECT COUNT(*)
           INTO v_tot_registro
           FROM sb_crc_vinculos_det
          WHERE fecha = p_fec_periodo;
         -- Actualizo la tabla de operaciones
         UPDATE sb_crc_vinculos
            SET tot_registro = nvl(v_tot_registro, 0)
          WHERE fec_periodo = p_fec_periodo;
         IF SQL%NOTFOUND THEN
            INSERT INTO sb_crc_vinculos
               (nom_referencia, fec_periodo, cod_entidad, tot_registro)
            VALUES
               ('VINCULOS', p_fec_periodo, v_cod_entidad, nvl(v_tot_registro, 0));
         END IF;
      ELSIF p_nom_tabla = 'SB_CRC_VINCULOS' THEN
         --2.- Tabla de Vinculos
         SELECT COUNT(*)
           INTO v_tot_registro
           FROM sb_crc_vinculos_det
          WHERE fecha = p_fec_periodo;
         -- Actualizo la tabla de operaciones
         UPDATE sb_crc_vinculos
            SET tot_registro = nvl(v_tot_registro, 0)
          WHERE fec_periodo = p_fec_periodo;
         IF SQL%NOTFOUND THEN
            INSERT INTO sb_crc_vinculos
               (nom_referencia, fec_periodo, cod_entidad, tot_registro)
            VALUES
               ('VINCULOS', p_fec_periodo, v_cod_entidad, nvl(v_tot_registro, 0));
         END IF;
      ELSIF p_nom_tabla = 'SB_CRC_SALDOS' THEN
         --3.- Tabla de Saldos
         SELECT COUNT(*)
           INTO v_tot_registro
           FROM sb_crc_saldos_det
          WHERE fecha = p_fec_periodo;
         -- Actualizo la tabla de operaciones
         UPDATE sb_crc_saldos
            SET tot_registro = nvl(v_tot_registro, 0)
          WHERE fec_periodo = p_fec_periodo;
         IF SQL%NOTFOUND THEN
            INSERT INTO sb_crc_saldos
               (nom_referencia, fec_periodo, cod_entidad, tot_registro)
            VALUES
               ('SALDOS', p_fec_periodo, v_cod_entidad, nvl(v_tot_registro, 0));
         END IF;
      ELSIF p_nom_tabla = 'SB_CRC_CLASIFICACIONES' THEN
         --4.- Tabla de Clasificaciones
         SELECT COUNT(1)
           INTO v_tot_registro
           FROM sb_crc_clasificaciones_det
          WHERE fecha = p_fec_periodo;
         -- Actualizo la tabla de operaciones
         UPDATE sb_crc_clasificaciones
            SET tot_registro = nvl(v_tot_registro, 0)
          WHERE fec_periodo = p_fec_periodo;
         IF SQL%NOTFOUND THEN
            INSERT INTO sb_crc_clasificaciones
               (nom_referencia, fec_periodo, cod_entidad, tot_registro)
            VALUES
               ('CLASIFICA', p_fec_periodo, v_cod_entidad, nvl(v_tot_registro, 0));
         END IF;
      ELSIF p_nom_tabla = 'SB_CRC_MOVIMIENTOS' THEN
         --5.- Tabla de Movimientos
         SELECT COUNT(*)
           INTO v_tot_registro
           FROM sb_crc_movimientos_det
          WHERE fecha = p_fec_periodo;
         -- Actualizo la tabla de movimientos
         UPDATE sb_crc_movimientos
            SET tot_registro = nvl(v_tot_registro, 0)
          WHERE fec_periodo = p_fec_periodo;
         IF SQL%NOTFOUND THEN
            INSERT INTO sb_crc_movimientos
               (nom_referencia, fec_periodo, cod_entidad, tot_registro)
            VALUES
               ('MOVIMIENTO', p_fec_periodo, v_cod_entidad, nvl(v_tot_registro, 0));
         END IF;
      ELSIF p_nom_tabla = 'SB_CRC_GARANTIAS' THEN
         --6.- Tabla de Garantias
         SELECT COUNT(*)
           INTO v_tot_registro
           FROM sb_crc_garantias_det
          WHERE fecha = p_fec_periodo;
         -- Actualizo la tabla de Garantias
         UPDATE sb_crc_garantias
            SET tot_registro = nvl(v_tot_registro, 0)
          WHERE fec_periodo = p_fec_periodo;
         IF SQL%NOTFOUND THEN
            INSERT INTO sb_crc_garantias
               (nom_referencia, fec_periodo, cod_entidad, tot_registro)
            VALUES
               ('GARANTIAS', p_fec_periodo, v_cod_entidad, nvl(v_tot_registro, 0));
         END IF;
      ELSIF p_nom_tabla = 'SB_CRC_OPE_GARANTIAS' THEN
         IF p_nom_referencia = 'OPEGARAN' THEN
            --7.- Tabla de Ope. Garantias Alta.
            SELECT COUNT(*)
              INTO v_tot_registro
              FROM sb_crc_ope_garantias_det
             WHERE fecha = p_fec_periodo
               AND nom_referencia = 'OPEGARAN';
            -- Actualizo la tabla de Ope. Garantias Alta
            UPDATE sb_crc_ope_garantias
               SET tot_registro = nvl(v_tot_registro, 0)
             WHERE fec_periodo = p_fec_periodo
               AND nom_referencia = 'OPEGARAN';
            IF SQL%NOTFOUND THEN
               INSERT INTO sb_crc_ope_garantias
                  (nom_referencia, fec_periodo, cod_entidad, tot_registro)
               VALUES
                  ('OPEGARAN', p_fec_periodo, v_cod_entidad, nvl(v_tot_registro, 0));
            END IF;
         ELSIF p_nom_referencia = 'OPEGARELI' THEN
            --8.- Tabla de Ope. Garantias Baja.
            SELECT COUNT(*)
              INTO v_tot_registro
              FROM sb_crc_ope_garantias_det
             WHERE fecha = p_fec_periodo
               AND nom_referencia = 'OPEGARELI';
            -- Actualizo la tabla de Ope. Garantias Baja
            UPDATE sb_crc_ope_garantias
               SET tot_registro = nvl(v_tot_registro, 0)
             WHERE fec_periodo = p_fec_periodo
               AND nom_referencia = 'OPEGARELI';
            IF SQL%NOTFOUND THEN
               INSERT INTO sb_crc_ope_garantias
                  (nom_referencia, fec_periodo, cod_entidad, tot_registro)
               VALUES
                  ('OPEGARELI', p_fec_periodo, v_cod_entidad, nvl(v_tot_registro, 0));
            END IF;
         END IF;
      ELSIF p_nom_tabla = 'SB_CRC_ACT_VINCULOS' THEN
         SELECT COUNT(*)
           INTO v_tot_registro
           FROM sb_crc_act_vinculos_det
          WHERE fecha = p_fec_periodo
            AND nom_referencia = 'VINCULOSD';
         UPDATE sb_crc_act_vinculos
            SET tot_registro = nvl(v_tot_registro, 0)
          WHERE fec_periodo = p_fec_periodo;
         IF SQL%NOTFOUND THEN
            INSERT INTO sb_crc_act_vinculos
               (nom_referencia, fec_periodo, cod_entidad, tot_registro)
            VALUES
               ('VINCULOSD', p_fec_periodo, v_cod_entidad, nvl(v_tot_registro, 0));
         END IF;
      END IF;
   END;
   PROCEDURE lp_obt_dat_cta_vencida(p_cod_persona IN VARCHAR2, p_sal_vencido OUT NUMBER, p_int_vencido OUT NUMBER) IS
      CURSOR c_vencidos IS
         SELECT nvl(SUM(nvl(pag_gen.fu_con_mon_a_moneda(b.cod_moneda, v_cod_mon_local, a.sal_capital, NULL), 0)), 0) sal_vencido,
                nvl(SUM(nvl(pag_gen.fu_con_mon_a_moneda(b.cod_moneda, v_cod_mon_local, a.sal_interes, NULL), 0)) +
                     SUM(nvl(pag_gen.fu_con_mon_a_moneda(b.cod_moneda, v_cod_mon_local, a.sal_int_documentado, NULL), 0)),
                     0) int_vencido
           FROM pr_cuotas a, pr_cta_prestamos b, ge_cta_clientes c
          WHERE a.nro_cuenta = b.nro_cuenta
            AND a.nro_cuenta = c.nro_cuenta
            AND b.nro_cuenta = c.nro_cuenta
            AND a.fec_vencimiento < v_fec_fin
            AND a.estado <> 'N'
            AND c.cod_persona = p_cod_persona
            AND c.relacion = 'P'
            AND (b.estado NOT IN ('N','I') OR (b.estado = 'I' AND
                to_date(fug_obt_paradicional(b.nro_cuenta, 'FEC_PAS_INCOBRABLE'), 'dd/mm/yyyy') IS NULL) OR
                (b.est_batch = 'I' AND
                to_date(fug_obt_paradicional(b.nro_cuenta, 'FEC_PAS_INCOBRABLE'), 'dd/mm/yyyy') IS NOT NULL AND
                ((v_fec_fin -
                to_date(fug_obt_paradicional(b.nro_cuenta, 'FEC_PAS_INCOBRABLE'), 'dd/mm/yyyy')) <= v_crc_can_dia_incobrable)))
         UNION
         SELECT nvl(SUM(nvl(pag_gen.fu_con_mon_a_moneda(b.cod_moneda, v_cod_mon_local, a.sal_capital, NULL), 0)), 0) sal_vencido,
                nvl(SUM(nvl(pag_gen.fu_con_mon_a_moneda(b.cod_moneda, v_cod_mon_local, a.sal_interes, NULL), 0)), 0) int_vencido
           FROM md_doc_detalles a, md_cta_documentos b, ge_cta_clientes c
          WHERE a.nro_cuenta = b.nro_cuenta
            AND a.nro_cuenta = c.nro_cuenta
            AND b.nro_cuenta = c.nro_cuenta
            AND a.fec_vencimiento < v_fec_fin
            AND c.cod_persona = p_cod_persona
            AND a.estado NOT IN ('N', 'S')
            AND NOT EXISTS (SELECT 1
                   FROM ge_par_dinamicos d
                  WHERE d.parametro = 'SIB_CRC_MAD_EXC_ARCHIVO'
                    AND d.cod_modalidad = b.cod_modalidad
                    AND nvl(d.val_parametro, 'N') = 'S');
   BEGIN
      FOR i IN c_vencidos LOOP
         p_sal_vencido := nvl(p_sal_vencido, 0) + nvl(i.sal_vencido, 0); --- se acumula los montos
         p_int_vencido := nvl(p_int_vencido, 0) + nvl(i.int_vencido, 0); --- se acumula los montos
      END LOOP;
   END;

   --- obtener deuda venta de cartera

   ---
   --- obtener deuda incobrable
      PROCEDURE lp_obt_dat_incobrable(p_cod_persona IN VARCHAR2, p_sal_vencido OUT NUMBER) IS
      v_fec_pas_incobrable  sb_crc_operaciones_det.fecha%TYPE;
      CURSOR c_vencidos IS
         SELECT nvl((nvl(pag_gen.fu_con_mon_a_moneda(b.cod_moneda, v_cod_mon_local, a.sal_capital, NULL), 0)), 0) sal_vencido,
                nvl((nvl(pag_gen.fu_con_mon_a_moneda(b.cod_moneda, v_cod_mon_local, a.sal_interes, NULL), 0)) +
                     (nvl(pag_gen.fu_con_mon_a_moneda(b.cod_moneda, v_cod_mon_local, a.sal_int_documentado, NULL), 0)),
                     0) int_vencido, b.nro_cuenta
           FROM pr_cuotas a, pr_cta_prestamos b, ge_cta_clientes c
          WHERE a.nro_cuenta = b.nro_cuenta
            AND a.nro_cuenta = c.nro_cuenta
            AND b.nro_cuenta = c.nro_cuenta
       --     AND a.fec_vencimiento < v_fec_fin
            AND a.estado = 'I'
            AND c.cod_persona = p_cod_persona
            AND c.relacion = 'P'
         UNION ALL
         SELECT nvl((nvl(pag_gen.fu_con_mon_a_moneda(b.cod_moneda, v_cod_mon_local, a.sal_capital, NULL), 0)), 0) sal_vencido,
                nvl((nvl(pag_gen.fu_con_mon_a_moneda(b.cod_moneda, v_cod_mon_local, a.sal_interes, NULL), 0)), 0) int_vencido,
                b.nro_cuenta
           FROM md_doc_detalles a, md_cta_documentos b, ge_cta_clientes c
          WHERE a.nro_cuenta = b.nro_cuenta
            AND a.nro_cuenta = c.nro_cuenta
            AND b.nro_cuenta = c.nro_cuenta
        ---    AND a.fec_vencimiento < v_fec_fin
            AND c.cod_persona = p_cod_persona
            AND a.estado ='I'
            AND v_fec_pas_incobrable IS NOT NULL AND ((v_fec_actual - v_fec_pas_incobrable) <= v_crc_can_dia_incobrable )
            AND NOT EXISTS (SELECT 1
                   FROM ge_par_dinamicos d
                  WHERE d.parametro = 'SIB_CRC_MAD_EXC_ARCHIVO'
                    AND d.cod_modalidad = b.cod_modalidad
                    AND nvl(d.val_parametro, 'N') = 'S')
          UNION ALL
          SELECT nvl((nvl(pag_gen.fu_con_mon_a_moneda(a.cod_moneda, v_cod_mon_local, a.sal_total, NULL), 0)), 0) sal_vencido,
                 0 int_vencido,
                 a.nro_cuenta
           FROM ov_cta_vencidas a, ge_cta_clientes b
          WHERE a.nro_cuenta = b.nro_cuenta
            AND b.relacion = 'P'
            AND b.cod_persona = p_cod_persona
            AND a.estado =  'I'
            AND (pag_cal.fu_obt_fec_actual(1) - NVL(a.fec_cam_estado, a.fec_apertura)) <= v_crc_can_dia_incobrable ;

        TYPE cursorVenc_type IS TABLE OF c_vencidos%ROWTYPE;
          regVenc cursorVenc_type;
   BEGIN
       OPEN c_vencidos;
        LOOP
        FETCH c_vencidos BULK COLLECT INTO regVenc ;
        FOR i IN 1 .. regVenc.count LOOP
         v_fec_pas_incobrable := to_date(fug_obt_paradicional(regVenc(i).nro_cuenta, 'PRE_FEC_PAS_INCOBRABLE'),'dd/mm/yyyy');

         IF v_fec_pas_incobrable IS NOT NULL AND ((v_fec_actual - v_fec_pas_incobrable) <= v_crc_can_dia_incobrable )THEN
            p_sal_vencido := (nvl(p_sal_vencido, 0)) + (nvl(regVenc(i).sal_vencido, 0)) + (nvl(regVenc(i).int_vencido,0)); --- se acumula los montos
         END IF;--7/10/2021 comentado, para no controlar tope de fecha de envio a incobrable.

        END LOOP;
      EXIT WHEN c_vencidos%NOTFOUND;
          END LOOP;
          CLOSE c_vencidos;
   END;

   ---

   PROCEDURE lp_obt_dat_sobregiro(p_cod_persona IN VARCHAR2, p_sal_sobregiro OUT NUMBER) IS
   BEGIN
      SELECT SUM(c.sal_ret_batch) + SUM(c.sal_blo_batch) + SUM(c.sal_tot_batch) sal_tot
        INTO p_sal_sobregiro
        FROM cc_cta_corrientes c
       WHERE c.nro_cuenta IN (SELECT nro_cuenta
                                FROM ge_cta_clientes g
                               WHERE g.cod_persona = p_cod_persona
                                 AND g.cod_modulo = 4);
   EXCEPTION
      WHEN OTHERS THEN
         p_sal_sobregiro := 0;
   END;
   -- funcion que verifica la existencia de la cuenta en el mes anterior.
   FUNCTION lf_ver_exi_saldos(p_nro_cuenta ge_cuentas.nro_cuenta%TYPE, p_fec_operacion DATE) RETURN VARCHAR2 IS
      v_result VARCHAR2(1);
   BEGIN
      SELECT 'S'--DISTINCT 'S'
        INTO v_result
        FROM sb_crc_saldos_det e
       WHERE e.nro_operacion = p_nro_cuenta
         AND e.sal_capital <> 0
         AND to_char(e.fecha, 'mmyyyy') = to_char(add_months(v_fec_fin, -1), 'mmyyyy')
         FETCH FIRST ROW ONLY;
      RETURN v_result;
   EXCEPTION
      WHEN no_data_found THEN
         BEGIN
            SELECT DISTINCT 'S'
              INTO v_result
              FROM dual
             WHERE p_fec_operacion BETWEEN v_fec_inicio AND v_fec_fin;
            RETURN v_result;
         EXCEPTION
            WHEN NO_DATA_FOUND THEN
                BEGIN
                   SELECT 'S'--DISTINCT 'S'
                    INTO v_result
                    FROM sb_crc_saldos_det e, ta_tarjetas tat
                    WHERE e.nro_operacion = tat.nro_tarjeta
                    and tat.nro_cuenta = p_nro_cuenta
                    and tat.rel_tarjeta = 0
                    AND e.nom_referencia = 'SALDOS'
                    AND e.sal_capital <> 0
                    AND to_char(e.fecha, 'mmyyyy') = to_char(add_months(v_fec_fin, -1), 'mmyyyy')
                    FETCH FIRST ROW ONLY;
                    RETURN v_result;
                EXCEPTION
                     WHEN no_data_found THEN
               RETURN 'N';
            WHEN OTHERS THEN
               RETURN 'N';
         END;
         END;
      WHEN OTHERS THEN
         RETURN 'N';
   END;
     -- funcion que verifica la existencia de la cuenta en el mes anterior.
   FUNCTION lf_ver_exi_saldos
   (
      p_nro_cuenta ge_cuentas.nro_cuenta%TYPE,
      p_fec_inicio DATE,
      p_fec_fin    DATE
   ) RETURN VARCHAR2 IS
      v_result VARCHAR2(1) default 'N';
   BEGIN
     begin
        SELECT 'S'
          INTO v_result
          FROM sb_crc_saldos_det e
         WHERE e.nro_operacion = p_nro_cuenta
           AND e.sal_capital <> 0
           AND to_char(e.fecha, 'mmyyyy') = to_char(add_months(p_fec_fin, -1), 'mmyyyy');
      exception
        when no_data_found then
          -- RABP-CNF-30-09-2014: Para optimizar busqueda
          BEGIN
            SELECT 'S'
              INTO v_result
              FROM sb_crc_operaciones_det d
             WHERE d.nro_operacion = p_nro_cuenta
               AND d.fecha BETWEEN p_fec_inicio AND p_fec_fin;
           EXCEPTION
             WHEN NO_DATA_FOUND THEN
               v_result := 'N';
             WHEN OTHERS THEN
               v_result := 'N';
           END;
      end;

      RETURN v_result;
   EXCEPTION
      WHEN OTHERS THEN
         RETURN v_result;
   END;
    FUNCTION lf_obt_tip_persona(p_cod_persona IN ba_personas.cod_persona%TYPE)
      RETURN CHAR AS
      v_tip_persona ba_personas.tipo%TYPE;
   BEGIN
      -- obtiene el tipo de persona
      SELECT a.tipo
        INTO v_tip_persona
        FROM ba_personas a
       WHERE a.cod_persona = p_cod_persona ;
      RETURN v_tip_persona ;

   EXCEPTION
      WHEN no_data_found THEN
         RETURN 'F' ;
      WHEN OTHERS THEN
         RETURN 'F' ;
   END;
   PROCEDURE lp_obt_dat_tarjeta(p_nro_cuenta         IN  ta_cta_tarjetas.nro_cuenta%TYPE,
                                p_fec_operacion      IN  sb_crc_saldos_det.fecha%TYPE,
                                p_cod_modalidad      OUT ta_cta_tarjetas.cod_modalidad%TYPE,
                                p_fec_apertura       OUT ta_cta_tarjetas.fec_apertura%TYPE,
                                p_sal_capital        OUT sb_crc_saldos_det.sal_capital%TYPE,
                                p_dia_atraso         OUT ta_cta_tarjetas.dia_mora%TYPE,
                                p_tip_cierre         OUT ta_cta_tarjetas.tip_cierre%TYPE,
                                p_tas_efectiva       OUT ta_cta_tarjetas.tas_efectiva%TYPE,
                                p_estado             OUT ge_cuentas.estado%TYPE,
                                p_fec_ult_operacion  OUT ta_cta_tarjetas.fec_ult_operacion%TYPE,
                                p_est_tarjeta        OUT sb_crc_saldos_det.est_tarjeta%TYPE,
                                p_mto_deu_anterior   OUT sb_crc_saldos_det.mto_deu_anterior%TYPE,
                                p_mto_pag_mes        OUT sb_crc_saldos_det.mto_pag_mes%TYPE,
                                p_mto_lin_credito    OUT sb_crc_saldos_det.mto_lin_credito%TYPE,
                                p_mto_com_mes        OUT sb_crc_saldos_det.mto_com_mes%TYPE,
                                p_mto_deu_facturar   OUT sb_crc_saldos_det.mto_deu_facturar%TYPE,
                                p_mto_cargo          OUT sb_crc_saldos_det.mto_cargo%TYPE) IS

   v_sal_deuda           NUMBER(20,2) := 0;
   v_mto_contingente     NUMBER(20,2) := 0;
   v_dev_no_cobrado      ge_cla_operaciones.dev_no_cobrado%TYPE;
   v_tot_prevision       ge_cla_operaciones.tot_prevision%TYPE;
   v_cat_automatica      ge_cla_operaciones.cat_automatica%TYPE;
   v_tot_gar_computables ge_cla_operaciones.tot_gar_computables%TYPE;

BEGIN
   v_existe := lf_ver_exi_saldos(p_nro_cuenta, p_fec_operacion);

   SELECT a.cod_modalidad,
          a.fec_apertura,
          CASE
              WHEN nvl((nvl(a.sal_facturar, 0) + nvl(a.sal_financiado, 0) + nvl(a.sal_facturado, 0) +
                       nvl(a.sal_cuo_pendientes, 0)), 0) < 0 THEN 0
              ELSE nvl((nvl(a.sal_facturar, 0) + nvl(a.sal_financiado, 0) + nvl(a.sal_facturado, 0) +
                       nvl(a.sal_cuo_pendientes, 0)), 0)
          END sal_capital,
          decode(a.estado, 'C', 0, nvl(a.dia_mora, 0)),
          decode(nvl(a.tas_financiacion, 0), 0, a.tas_efectiva, a.tas_financiacion) tas_efectiva,
          a.tip_cierre,
          decode(a.cat_automatica, '1', 'C', '2', 'V', '3', 'G', '4', 'G', 'M') estado,
          a.fec_ult_operacion,
          nvl(a.sal_facturar, 0) + nvl(a.sal_facturado, 0) + nvl(a.sal_financiado, 0) + nvl(a.sal_cuo_pendientes, 0),
          nvl(a.lin_credito, 0) + nvl(a.lin_cuotas,0)
     INTO p_cod_modalidad, p_fec_apertura, p_sal_capital, p_dia_atraso, p_tas_efectiva, p_tip_cierre, p_estado,
          p_fec_ult_operacion,
          v_sal_deuda,
          p_mto_lin_credito
     FROM ta_cta_tarjetas a, ge_cta_clientes b, ge_clientes c, ge_cuentas d
    WHERE a.nro_cuenta = b.nro_cuenta
      AND b.relacion = 'P'
      AND b.cod_persona = c.cod_persona
      AND a.nro_cuenta = d.nro_cuenta
      AND a.nro_cuenta = p_nro_cuenta
      AND (a.estado <> 'C' OR (a.estado = 'C'
          AND (nvl((nvl(a.sal_facturar, 0) + nvl(a.sal_financiado, 0) + nvl(a.sal_facturado, 0) +
                                        nvl(a.sal_cuo_pendientes, 0)), 0)) <> 0 AND v_existe = 'S'))
      AND NOT EXISTS (SELECT 1
             FROM ge_par_dinamicos p
            WHERE p.parametro = 'SIB_CRC_MAD_EXC_ARCHIVO'
              AND p.cod_modalidad = a.cod_modalidad
              AND nvl(p.val_parametro, 'N') = 'S');

   -- Obtener monto contingente y estado tarjeta desde lp_obt_dat_cla_operaciones
   lp_obt_dat_cla_operaciones(p_nro_cuenta,
                              v_dev_no_cobrado,
                              v_tot_prevision,
                              v_mto_contingente,
                              v_tot_gar_computables,
                              v_cat_automatica);

   IF (v_sal_deuda + v_mto_contingente) <> 0 THEN
      p_est_tarjeta := 1;
   ELSE
      p_est_tarjeta := 2;
   END IF;

   BEGIN
      SELECT nvl(mto_pago, 0),
             nvl(mto_car_mes, 0),
             nvl(deu_ant, 0),
             nvl(val_deu_cuo_facturar, 0),
             nvl(int_car_dev_suspenso, 0)
        INTO p_mto_pag_mes,
             p_mto_com_mes,
             p_mto_deu_anterior,
             p_mto_deu_facturar,
             p_mto_cargo
        FROM ta_ext_cli_cab_gp
       WHERE nro_cuenta = p_nro_cuenta
         AND fec_cierre = (SELECT MAX(fec_cierre)
                             FROM ta_ext_cli_cab_gp
                            WHERE nro_cuenta = p_nro_cuenta
                              AND fec_cierre <= v_fec_fin);
   EXCEPTION
      WHEN NO_DATA_FOUND THEN
         p_mto_pag_mes      := 0;
         p_mto_com_mes      := 0;
         p_mto_deu_anterior := 0;
         p_mto_deu_facturar := 0;
         p_mto_cargo        := 0;
   END;

EXCEPTION
   WHEN NO_DATA_FOUND THEN
      NULL;
   WHEN OTHERS THEN
      p_cod_modalidad     := NULL;
      p_fec_apertura      := NULL;
      p_sal_capital       := 0;
      p_dia_atraso        := 0;
      p_estado            := NULL;
      p_fec_ult_operacion := NULL;
      p_est_tarjeta       := NULL;
      p_mto_deu_anterior  := 0;
      p_mto_pag_mes       := 0;
      p_mto_lin_credito   := 0;
      p_mto_com_mes       := 0;
      p_mto_deu_facturar  := 0;
      p_mto_cargo         := 0;
   END;
   PROCEDURE lp_obt_dat_tarjeta
   (
      p_nro_cuenta       IN ta_cta_tarjetas.nro_cuenta%TYPE,
      p_cod_modalidad    OUT ta_cta_tarjetas.cod_modalidad%TYPE,
      p_fec_apertura     OUT ta_cta_tarjetas.fec_apertura%TYPE,
      p_sal_capital      OUT sb_crc_saldos_det.sal_capital%TYPE,
      p_dia_atraso       OUT ta_cta_tarjetas.dia_mora%TYPE,
      p_cod_tip_cierre   OUT ta_cta_tarjetas.cod_tip_cierre%TYPE,
      p_tas_efectiva     OUT ta_cta_tarjetas.tas_efectiva%TYPE,
      p_cod_moneda       OUT ge_cuentas.cod_moneda%TYPE,
      p_cod_sec_contable OUT ge_clientes.cod_sec_contable%TYPE,
      p_cod_tip_deudor   OUT ge_clientes.cod_tip_deudor%TYPE,
      p_residente        OUT ge_clientes.residente%TYPE,
      p_estado           OUT ge_cuentas.estado%TYPE
   ) IS
   BEGIN
      v_existe := lf_ver_exi_saldos(p_nro_cuenta, v_fec_inicio, v_fec_fin);
      SELECT a.cod_modalidad,
             nvl(a.fec_apertura, e.fec_emision) fec_apertura,
             -- RABP-CNF-30-09-2014: Se comenta para obtener el saldo capital como lo hacia el CRC Viejo
             /*nvl((nvl(a.sal_facturar, 0) + nvl(a.sal_financiado, 0) + nvl(a.sal_facturado, 0) +
                 nvl(a.sal_cuo_pendientes, 0)), 0) sal_capital,*/
             /*nvl(a.sal_procesadora, 0)*/
             CASE
                 WHEN nvl((nvl(a.sal_facturar, 0) + nvl(a.sal_financiado, 0) + nvl(a.sal_facturado, 0) +
                          nvl(a.sal_cuo_pendientes, 0)),
                          0) < 0 THEN
                  0
                 ELSE
                  nvl((nvl(a.sal_facturar, 0) + nvl(a.sal_financiado, 0) + nvl(a.sal_facturado, 0) +
                      nvl(a.sal_cuo_pendientes, 0)),
                      0)
              END sal_capital,
             nvl(a.dia_mora, 0),
             decode(nvl(a.tas_financiacion, 0), 0, a.tas_efectiva, a.tas_financiacion) tas_efectiva,
             a.cod_tip_cierre,
             d.cod_moneda,
             c.cod_sec_contable,
             c.cod_tip_deudor,
             c.residente,
             decode(a.cat_automatica, '1', 'C', '2', 'V', '3', 'G', '4', 'G', 'M') estado
        INTO p_cod_modalidad,
             p_fec_apertura,
             p_sal_capital,
             p_dia_atraso,
             p_tas_efectiva,
             p_cod_tip_cierre,
             p_cod_moneda,
             p_cod_sec_contable,
             p_cod_tip_deudor,
             p_residente,
             p_estado
        FROM ta_cta_tarjetas a, ge_cta_clientes b, ge_clientes c, ge_cuentas d, ta_tarjetas e
       WHERE a.nro_cuenta = b.nro_cuenta
         AND b.relacion = 'P'
         AND b.cod_persona = c.cod_persona
         AND a.nro_cuenta = d.nro_cuenta
         AND a.nro_cuenta = e.nro_cuenta
         AND e.cod_persona = b.cod_persona
         AND ((v_cod_entidad IN (2079, 1043) AND e.vigente = 'S') OR
             (v_cod_entidad NOT IN (1028, 2079, 1043)))
         AND a.nro_cuenta = p_nro_cuenta
         AND e.nro_tarjeta = (SELECT MAX(k.nro_tarjeta)
                                FROM ta_tarjetas k
                               WHERE k.nro_cuenta = e.nro_cuenta
                                 AND k.cod_persona = b.cod_persona)
         AND (a.estado <> 'C' OR
             (a.estado = 'C' --Canceladas en el mes de informe.
             AND (nvl((nvl(a.sal_facturar, 0) + nvl(a.sal_financiado, 0) +
                        nvl(a.sal_facturado, 0) + nvl(a.sal_cuo_pendientes, 0)), 0)) = 0 AND
             v_existe = 'S'))
         AND NOT EXISTS (SELECT 1
                FROM ge_par_dinamicos p
               WHERE p.parametro = 'SIB_CRC_MAD_EXC_ARCHIVO'
                 AND p.cod_modalidad = a.cod_modalidad
                 AND nvl(p.val_parametro, 'N') = 'S')
         AND not exists (SELECT 1 -- No considerar las TC vinculadas a Op.Vencidas. mismo control en inventario
                              FROM ov_cta_vencidas v
                             WHERE v.nro_cta_origen = a.nro_cuenta
                             AND v.estado <> 'C');
   EXCEPTION
      WHEN NO_DATA_FOUND THEN
         NULL;
      WHEN OTHERS THEN
         p_cod_modalidad    := NULL;
         p_fec_apertura     := NULL;
         p_sal_capital      := 0;
         p_dia_atraso       := 0;
   END;
   FUNCTION lf_obt_dat_des_documentos(p_cod_persona IN VARCHAR2, p_tip_descuento IN VARCHAR2) RETURN VARCHAR2 IS
      v_existe VARCHAR2(1);
   BEGIN
      SELECT DISTINCT 'S'
        INTO v_existe
        FROM ge_cta_clientes c
       WHERE c.cod_persona = p_cod_persona
         AND nvl(FUG_OBT_PARDINAMICO('TIP_DES_DOCUMENTOS', 6, c.cod_modalidad, null, null), 'X') = (p_tip_descuento);
      RETURN v_existe;
   EXCEPTION
      WHEN OTHERS THEN
         RETURN 'N';
   END;
   FUNCTION lf_obt_ope_persona(p_cod_persona IN VARCHAR2, p_cod_modulo IN ge_cta_clientes.cod_modulo%TYPE) RETURN VARCHAR2 IS
      v_existe VARCHAR2(1);
   BEGIN
      SELECT 'S'
        INTO v_existe
        FROM ge_cta_clientes c
       WHERE c.nro_cuenta IN (SELECT nro_cuenta
                                FROM ge_cta_clientes g
                               WHERE g.cod_persona = p_cod_persona
                                 AND cod_modulo = p_cod_modulo);

      RETURN v_existe;
   EXCEPTION
      WHEN OTHERS THEN
         RETURN 'N';
   END;

   -- Obtiene el rubro del inventario segun la situacion, es utilizada para las cuentas que tienen
   -- Dos cuentas tip_saldo  Capital.
   FUNCTION lf_obt_rub_inventario(p_nro_cuenta IN VARCHAR2, p_tip_saldo IN VARCHAR2, p_situacion IN VARCHAR2)
      RETURN VARCHAR2 IS
      v_cod_rubro cb_rubros.cod_rubro%TYPE;
   BEGIN
      BEGIN
         SELECT a.cod_rubro
           INTO v_cod_rubro
           FROM cb_sal_inventarios a, cb_sal_inventarios_det d
          WHERE a.nro_referencia = d.nro_referencia
            AND d.nro_cuenta = p_nro_cuenta
            AND a.tip_saldo = p_tip_saldo
            AND a.cod_sec_contable IS NOT NULL
            AND a.residente IS NOT NULL
            AND (a.situacion = p_situacion OR p_situacion IS NULL)
            AND a.tip_operacion IS NOT NULL
            AND a.tip_interes IS NOT NULL;
      EXCEPTION
         WHEN no_data_found THEN
            RETURN NULL;
         WHEN too_many_rows THEN
            SELECT DISTINCT a.cod_rubro
              INTO v_cod_rubro
              FROM cb_sal_inventarios a, cb_sal_inventarios_det d
             WHERE a.nro_referencia = d.nro_referencia
               AND d.nro_cuenta = p_nro_cuenta
               AND a.tip_saldo = p_tip_saldo
               AND a.cod_sec_contable IS NOT NULL
               AND a.residente IS NOT NULL
               AND (a.situacion = p_situacion OR p_situacion IS NULL)
               AND d.sal_actual <> 0
               AND a.tip_operacion IS NOT NULL
               AND a.tip_interes IS NOT NULL;
         WHEN OTHERS THEN
            RETURN NULL;
      END;
      RETURN v_cod_rubro;
   EXCEPTION
      WHEN OTHERS THEN
         RETURN NULL;
   END;

   -- esta funcion verifica si una cuenta tiene mas de un tipo en operaciones (usado en ahorros vista)
   FUNCTION lf_ver_cta_operaciones(p_nro_cuenta ah_devengados.nro_cuenta%TYPE) RETURN VARCHAR2 IS
      v_cantidad number;
   BEGIN
      SELECT count(*)
        INTO v_cantidad
        FROM sb_crc_operaciones_det
       WHERE nro_operacion = p_nro_cuenta;
      IF v_cantidad > 1 THEN
         RETURN 'S'; -- tiene mas de una cuenta
      ELSE
         RETURN 'N';
      END IF;
   EXCEPTION
      WHEN no_data_found THEN
         RETURN 'N';
      WHEN OTHERS THEN
         RETURN 'N';
   END;

   FUNCTION lf_obt_int_dev_acumulado(p_nro_cuenta ah_devengados.nro_cuenta%TYPE) RETURN NUMBER IS
      v_dev_acumulado ah_devengados.mto_dev_acumulado%TYPE;
   BEGIN
      SELECT SUM(a.mto_dev_acumulado)
        INTO v_dev_acumulado
        FROM ah_devengados a
       WHERE nro_cuenta = p_nro_cuenta;
      --si el v_mto_dev_acumulado es negativo quiere decir que el CDA se cancelo
      --antes de su fecha, en ese caso devolver 0
      IF v_dev_acumulado < 0 THEN
         v_dev_acumulado := 0;
      END IF;

      RETURN nvl(v_dev_acumulado, 0);
   EXCEPTION
      WHEN no_data_found THEN
         RETURN 0;
      WHEN OTHERS THEN
         RETURN 0;
   END;

   --- Funcion que retorna la cantidad de dias de sobregiro
   PROCEDURE lp_obt_can_dia_sobregiro(p_nro_cuenta IN ge_cuentas.nro_cuenta%TYPE,
                                      p_can_dias   OUT cc_sobregiros_res.can_dia_sobregiro%TYPE) IS
      v_can_dias      cc_sobregiros_res.can_dia_sobregiro%TYPE;
      v_tie_sobregiro VARCHAR2(1);

   BEGIN
      SELECT can_dia_sobregiro
        INTO v_can_dias
        FROM cc_sobregiros_res
       WHERE nro_cuenta = p_nro_cuenta;
      p_can_dias := v_can_dias;
   EXCEPTION
      WHEN no_data_found THEN
         BEGIN
            SELECT 'S'
              INTO v_tie_sobregiro
              FROM cc_cta_corrientes a
             WHERE nro_cuenta = p_nro_cuenta
               AND nvl(a.sal_tot_batch, 0) - nvl(a.sal_ret_batch, 0) - nvl(a.sal_blo_batch, 0) < 0;
            IF v_fec_actual = pag_cal.g_ult_dia_mes_habil AND nvl(v_tie_sobregiro, 'N') = 'S' THEN
               --- si es fin de mes
               SELECT v_fec_proxima - v_fec_actual
                 INTO v_can_dias
                 FROM dual;
            END IF;
         EXCEPTION
            WHEN OTHERS THEN
               v_can_dias := 0;
         END;
         p_can_dias := v_can_dias; --- retorna cantidad de dias
   END;
   -- Procedimiento de generacion de Archivo de Operaciones
   PROCEDURE lp_log_crc(rp_slcrc sb_log_crc%ROWTYPE) IS
   BEGIN
      INSERT INTO sb_log_crc
         (fecha, nom_referencia, usu_insercion, fec_insercion, mensaje, nro_registro)
      VALUES
         (rp_slcrc.fecha,
          rp_slcrc.nom_referencia,
          rp_slcrc.usu_insercion,
          rp_slcrc.fec_insercion,
          rp_slcrc.mensaje,
          rp_slcrc.nro_registro);
   END;

   -- Procedimiento Sobrecargado de logueo en sb_log_crc
   PROCEDURE lp_log_crc(reg_slcrc rp_slcrc_type) IS
    l_error_count number;
   BEGIN

    FORALL i IN 1 .. reg_slcrc.count SAVE EXCEPTIONS
      INSERT INTO sb_log_crc
         (fecha, nom_referencia, usu_insercion, fec_insercion, mensaje, nro_registro)
      VALUES
         (reg_slcrc(i).fecha,
          reg_slcrc(i).nom_referencia,
          reg_slcrc(i).usu_insercion,
          reg_slcrc(i).fec_insercion,
          reg_slcrc(i).mensaje,
          reg_slcrc(i).nro_registro);

        EXCEPTION WHEN OTHERS THEN
          l_error_count := SQL%BULK_EXCEPTIONS.count;
        FOR indx IN 1 .. SQL%BULK_EXCEPTIONS.COUNT  LOOP
             RAISE_APPLICATION_ERROR(-20000, 'ERROR insertando en ge_clientes_nov ' ||  SQLERRM(-SQL%BULK_EXCEPTIONS(indx).ERROR_CODE));
        END LOOP;
     END;



   FUNCTION lf_obt_cod_conyuge(p_cod_persona IN ba_personas.cod_persona%TYPE) RETURN VARCHAR2 IS
      v_cod_conyuge ba_personas.cod_persona%TYPE;
   BEGIN
      SELECT v.cod_per_vinculo
        INTO v_cod_conyuge
        FROM ba_vinculos v
       WHERE v.tipo = 'E'
         AND v.cod_persona = p_cod_persona
         AND v_inc_conyuges = 'S'
         AND v_inc_cla_conyuges = 'S'
      UNION
      SELECT v.cod_persona
        FROM ba_vinculos v
       WHERE v.tipo = 'E'
         AND v.cod_per_vinculo = p_cod_persona
         AND v_inc_conyuges = 'S'
         AND v_inc_cla_conyuges = 'S';
      RETURN v_cod_conyuge;
   EXCEPTION
      WHEN NO_DATA_FOUND THEN
         v_cod_conyuge := NULL;
         RETURN v_cod_conyuge;
      WHEN OTHERS THEN
         v_cod_conyuge := NULL;
         RETURN v_cod_conyuge;
   END;

   FUNCTION lf_obt_cod_per_codeudor(p_cod_persona IN ba_personas.cod_persona%TYPE) RETURN VARCHAR2 IS
      v_cod_per_codeudor ba_personas.cod_persona%TYPE;
   BEGIN
      SELECT distinct a.cod_persona
        INTO v_cod_per_codeudor
        FROM it.ge_cta_clientes a,it.ge_cuentas b
       WHERE relacion NOT IN ('P', 'A', 'D')
         and a.cod_persona = p_cod_persona
         and a.nro_cuenta =  b.nro_cuenta
         and b.estado <> 'N';

        return v_cod_per_codeudor;
   EXCEPTION
      WHEN OTHERS THEN
         v_cod_per_codeudor := NULL;
         RETURN v_cod_per_codeudor;
   END;
   FUNCTION lf_es_cuo_vencida
   (
      p_nro_cuenta IN ge_cla_operaciones.nro_cuenta%TYPE,
      p_nro_cuota  IN pr_cuotas.nro_cuota%TYPE
   ) RETURN VARCHAR2 IS
      v_es_vencida VARCHAR2(1);
   BEGIN
      SELECT DISTINCT 'S'
        INTO v_es_vencida
        FROM pr_cuotas a
       WHERE a.nro_cuenta = p_nro_cuenta
         AND estado <> 'N'
         AND fec_vencimiento < v_fec_fin
         AND a.nro_cuota = p_nro_cuota;
      RETURN v_es_vencida;
   EXCEPTION
      WHEN OTHERS THEN
         v_es_vencida := 'N';
         RETURN v_es_vencida;
   END;
   FUNCTION lf_can_cuo_rrr(p_nro_cuenta IN ge_cla_operaciones.nro_cuenta%TYPE) RETURN NUMBER IS
      v_can_cuotas NUMBER;
   BEGIN
      SELECT COUNT(*) INTO v_can_cuotas FROM pr_cobros_rrr WHERE nro_cta_renovada = p_nro_cuenta;
      RETURN v_can_cuotas;
   EXCEPTION
      WHEN OTHERS THEN
         RETURN 1;
   END;

   PROCEDURE lp_obt_mto_rie_codeudor(p_cod_persona IN ba_personas.cod_persona%TYPE,
                                     p_cod_conyuge IN ba_personas.cod_persona%TYPE,
                                     p_mto_riesgo  OUT NUMBER) IS

     CURSOR c_riesgo IS
     SELECT SUM(nvl(a.sal_capital, 0) + nvl(a.sal_int_dev_no_cobrado, 0) + nvl(a.mto_contingencia, 0)) sal_capital,
            b.cod_persona
          FROM sb_crc_saldos_det a,
               (SELECT *
                  FROM sb_crc_vinculos_det c
                 WHERE c.tip_vinculo IN (002, 004, 005, 006, 007, 010)
                   AND c.cod_modulo <> 3) b
         WHERE a.fecha = v_fec_fin
           AND a.nro_operacion = b.nro_operacion
           ---AND a.cod_modulo <> 3
           AND nvl(a.cod_modulo,1) <> 3--para obtener codeudores de migracion vta cartera--FIELDESK-34615
           AND NOT EXISTS (SELECT 1 -- Se excluyen operaciones de vta de cartera
                             FROM sb_crc_vta_carteras v
                              where (v.nro_cuenta_bt = a.nro_operacion or v.nro_cuenta = a.nro_operacion)
                              and v.estado_vta_cartera='C')
        AND b.cod_persona = p_cod_persona
      GROUP BY b.cod_persona
      UNION
      SELECT o.sal_capital, o.cod_persona
      FROM sv_crc_mon_codeudor o
      WHERE o.fecha=v_fec_fin
      AND o.cod_persona = p_cod_persona;

   BEGIN
      FOR i IN c_riesgo LOOP
         p_mto_riesgo := nvl(p_mto_riesgo, 0) + nvl(i.sal_capital, 0);
      END LOOP;
   EXCEPTION
      WHEN NO_DATA_FOUND THEN
         p_mto_riesgo := 0;
      WHEN OTHERS THEN
         p_mto_riesgo := 0;
   END;
   --- Retorna el Total SR y Total TR
   PROCEDURE lp_obt_dat_cla_rie_total(p_cod_persona  IN ge_cla_operaciones.cod_persona%TYPE,
                                      p_tot_deu_real OUT ge_cla_operaciones.tot_deu_real%TYPE) IS
   BEGIN
      SELECT nvl(SUM(a.tot_deu_real), 0)
        INTO p_tot_deu_real
        FROM gv_cla_operaciones a, ge_cta_clientes c ----fieldesk-19388
       WHERE a.cod_persona = p_cod_persona
         --and a.cod_modalidad not in (690,152)--fideicomiso 152
         and not exists (select 1 from ba_cod_referencias where dominio = 'COD_MAD_FIDEICOMISO' and val_minimo = a.cod_modalidad) --fieldesk-19388
         AND a.cod_estado <> 'I'
         AND c.cod_persona = a.cod_persona
         AND c.relacion = 'P'
         AND c.nro_cuenta = a.nro_cuenta
         AND nvl(fup_obt_tip_descuento(a.cod_modalidad), 'X') NOT IN ('D', 'C')
         AND a.cod_modulo <> 3;
   EXCEPTION
      WHEN OTHERS THEN
         p_tot_deu_real := 0;
   END;
   --- Retorna el Total dc
   PROCEDURE lp_obt_mto_rie_documento(p_cod_persona IN ge_cla_operaciones.cod_persona%TYPE,
                                      p_mto_riesgo  OUT ge_cla_operaciones.tot_deu_real%TYPE) IS
   BEGIN
      SELECT nvl(SUM(a.tot_deu_real), 0)
        INTO p_mto_riesgo
        FROM gv_cla_operaciones a, ge_cta_clientes c ----fieldesk-19388
       WHERE a.cod_persona = p_cod_persona
         AND c.cod_persona = a.cod_persona
         AND c.relacion = 'P'
         AND c.nro_cuenta = a.nro_cuenta
         AND a.cod_estado <> 'I'
         AND nvl(fup_obt_tip_descuento(a.cod_modalidad), 'X') IN ('D', 'C');
   EXCEPTION
      WHEN OTHERS THEN
         p_mto_riesgo := 0;
   END;
   PROCEDURE lp_obt_dat_cla_operaciones(p_nro_cuenta          IN ge_cla_operaciones.nro_cuenta%TYPE,
                                        p_dev_no_cobrado      OUT ge_cla_operaciones.dev_no_cobrado%TYPE,
                                        p_tot_prevision       OUT ge_cla_operaciones.tot_prevision%TYPE,
                                        p_tot_deu_contingente OUT ge_cla_operaciones.tot_deu_contingente%TYPE,
                                        p_tot_gar_computables OUT ge_cla_operaciones.tot_gar_computables%TYPE,
                                        p_cat_automatica      OUT ge_cla_operaciones.cat_automatica%TYPE) IS
   BEGIN
      SELECT nvl(dev_no_cobrado, 0),
            (nvl(tot_prevision, 0) + nvl(mto_pre_total, 0)),
             nvl(tot_deu_contingente, 0),
             nvl(tot_gar_computables, 0),
             nvl(cat_automatica, 1)
        INTO p_dev_no_cobrado,
             p_tot_prevision,
             p_tot_deu_contingente,
             p_tot_gar_computables,
             p_cat_automatica
        FROM ge_cla_operaciones
       WHERE nro_cuenta = p_nro_cuenta;
   EXCEPTION
      WHEN OTHERS THEN
         p_dev_no_cobrado      := 0;
         p_tot_prevision       := 0;
         p_tot_deu_contingente := 0;
         p_tot_gar_computables := 0;
         p_cat_automatica      := 1;
   END;
     PROCEDURE lp_obt_dat_cla_operaciones
   (
      p_cod_modulo          IN  ge_cla_operaciones.cod_modulo%TYPE,
      p_nro_cuenta          IN  ge_cla_operaciones.nro_cuenta%TYPE,
      p_cod_mon_iso         IN  sb_crc_operaciones_det.cod_moneda%TYPE,
      p_dev_no_cobrado      OUT ge_cla_operaciones.dev_no_cobrado%TYPE,
      p_tot_prevision       OUT ge_cla_operaciones.tot_prevision%TYPE,
      p_tot_deu_contingente OUT ge_cla_operaciones.tot_deu_contingente%TYPE,
      p_tot_gar_computables OUT ge_cla_operaciones.tot_gar_computables%TYPE,
      p_cat_automatica      OUT ge_cla_operaciones.cat_automatica%TYPE
   ) IS
     v_cotizacion  ge_cotizaciones.val_conversion%TYPE;
     v_can_decimal ge_par_dinamicos.val_parametro%TYPE;
   BEGIN
      v_cotizacion  := nvl(fug_obt_cotizacion(p_cod_mon_iso, v_fec_fin),1);
      v_can_decimal := nvl(fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', NULL, NULL, v_cod_mon_local, NULL),0);
      SELECT nvl(dev_no_cobrado, 0),
             nvl(tot_prevision, 0),
             nvl(tot_deu_contingente, 0),
             nvl(tot_gar_computables, 0),
             nvl(cat_automatica, 1)
        INTO p_dev_no_cobrado,
             p_tot_prevision,
             p_tot_deu_contingente,
             p_tot_gar_computables,
             p_cat_automatica
        FROM ge_cla_operaciones
       WHERE nro_cuenta = p_nro_cuenta;
      IF p_cod_modulo = 5 THEN
         BEGIN
           SELECT NVL(t.monto,0) - NVL(t.tot_prv_contingencia,0)
             INTO p_tot_prevision
             FROM ta_previsiones t
            WHERE t.nro_cuenta = p_nro_cuenta
              AND t.fecha = ( SELECT MAX(fecha)
                                FROM ta_previsiones p
                               WHERE p.nro_cuenta = t.nro_cuenta );
         EXCEPTION
           WHEN OTHERS THEN
             NULL;
         END;
         p_tot_prevision := round(p_tot_prevision * v_cotizacion, v_can_decimal);
      ELSIF p_cod_modulo = 4 THEN
         BEGIN
           SELECT NVL(c.monto,0) - NVL(c.tot_prv_contingencia,0)
             INTO p_tot_prevision
             FROM cc_previsiones c, cc_sobregiros_res r
            WHERE c.nro_cuenta = p_nro_cuenta
              AND c.fecha = ( SELECT MAX(fecha)
                                FROM cc_previsiones p
                               WHERE p.nro_cuenta = c.nro_cuenta )
              AND r.nro_cuenta(+) = c.nro_cuenta;
         EXCEPTION
           WHEN OTHERS THEN
             NULL;
         END;
         p_tot_prevision := round(p_tot_prevision * v_cotizacion, v_can_decimal);
      END IF;
   EXCEPTION
      WHEN OTHERS THEN
         p_dev_no_cobrado      := 0;
         p_tot_prevision       := 0;
         p_tot_deu_contingente := 0;
         p_tot_gar_computables := 0;
         p_cat_automatica      := 1;
   END;

   PROCEDURE lp_obt_dat_mto_cuo_pre(p_nro_cuenta    IN ge_cla_operaciones.nro_cuenta%TYPE,
                                    p_nro_cuota     IN pr_cuotas.nro_cuota%TYPE,
                                    p_can_cuotas    IN pr_cta_prestamos.can_cuotas%TYPE,
                                    p_tot_prevision IN OUT ge_cla_operaciones.tot_prevision%TYPE

                                    ) IS
   BEGIN
      p_tot_prevision := (nvl(p_tot_prevision, 0) * nvl(p_nro_cuota, 0)) / nvl(p_can_cuotas, 1);
   EXCEPTION
      WHEN OTHERS THEN
         p_tot_prevision := 0;
   END;


    PROCEDURE lp_obt_mto_vta_cartera
    (
       p_nro_documento     IN ba_personas.nro_documento%TYPE,
       p_mto_vta_cartera OUT ge_cla_operaciones.tot_deu_real%TYPE
    ) IS
       v_fec_cancelacion DATE;
       v_mto_cartera     ge_cla_operaciones.tot_deu_real%TYPE;

    BEGIN
     --- venta de cartera obtengo capital e interes del cobro de la fecha de cancelacion --
           SELECT --sum( nvl(pag_gen.fu_con_mon_a_moneda(cod_moneda, v_cod_mon_local,nvl(sal_capital, 0) + nvl(dev_no_cobrado, 0), NULL), 0))
             sum(nvl(sal_capital, 0))
            into p_mto_vta_cartera
            FROM sb_crc_vta_carteras v
           WHERE v.nro_documento = p_nro_documento
           and v.estado_vta_cartera = 'C';

    EXCEPTION
       WHEN NO_DATA_FOUND THEN
          p_mto_vta_cartera := 0;
       WHEN OTHERS THEN
          p_mto_vta_cartera := 0;
    END;

   PROCEDURE lp_obt_dat_cla_persona(p_cod_persona           IN ge_cla_operaciones.cod_persona%TYPE,
                                    p_tot_deu_real          OUT ge_cla_operaciones.tot_deu_real%TYPE,
                                    p_tot_prevision         OUT ge_cla_operaciones.tot_prevision%TYPE,
                                    p_tot_deu_contingente   OUT ge_cla_operaciones.tot_deu_contingente%TYPE,
                                    p_tot_gar_computables   OUT ge_cla_operaciones.tot_gar_computables%TYPE,
                                    p_tot_cap_pri_prevision OUT ge_cla_operaciones.tot_cap_pri_prevision%TYPE,
                                    p_tot_int_pri_prevision OUT ge_cla_operaciones.tot_int_pri_prevision%TYPE,
                                    p_tot_cap_seg_prevision OUT ge_cla_operaciones.tot_cap_seg_prevision%TYPE,
                                    p_tot_int_seg_prevision OUT ge_cla_operaciones.tot_int_seg_prevision%TYPE) IS
   BEGIN
      SELECT nvl(SUM(a.tot_prevision), 0), nvl(SUM(a.tot_deu_total), 0), nvl(SUM(a.tot_deu_contingente), 0),
             nvl(SUM(a.tot_gar_computables), 0), nvl(SUM(a.tot_cap_pri_prevision), 0),
             nvl(SUM(a.tot_int_pri_prevision), 0), nvl(SUM(a.tot_cap_seg_prevision), 0),
             nvl(SUM(a.tot_int_seg_prevision), 0)
        INTO p_tot_prevision, p_tot_deu_real, p_tot_deu_contingente, p_tot_gar_computables, p_tot_cap_pri_prevision,
             p_tot_int_pri_prevision, p_tot_cap_seg_prevision, p_tot_int_seg_prevision
        FROM gv_cla_operaciones a
       WHERE a.cod_persona = p_cod_persona
         AND a.cod_estado <> 'I';-- NO INCLUIR INCOBRABLES.
   EXCEPTION
      WHEN OTHERS THEN
         p_tot_prevision         := 0;
         p_tot_deu_contingente   := 0;
         p_tot_gar_computables   := 0;
         p_tot_cap_pri_prevision := 0;
         p_tot_int_pri_prevision := 0;
         p_tot_cap_seg_prevision := 0;
         p_tot_int_seg_prevision := 0;
   END;
function lf_rem_car_especiales(p_cad_car_entrada in varchar2) return varchar2 is
    v_cad_car_salida varchar2(4000) := null;
    v_cad_car_validos VARCHAR2(100) := 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789. ';
    i NUMBER;
begin
    -- reemplazar caracteres acento agudo(´),
    -- con diéresis, acento circunflejo(^),
    -- acento grave(`), letra especiales
    if p_cad_car_entrada is not null then
       v_cad_car_salida := p_cad_car_entrada;
    FOR i IN 1..LENGTH(v_cad_car_salida) LOOP
        IF INSTR(v_cad_car_validos, SUBSTR(v_cad_car_salida, i, 1)) = 0 THEN
          if v_cad_car_salida like '%ÃŒ%' then
            v_cad_car_salida := replace(v_cad_car_salida,'ÃŒ','U');
            end if;
            if v_cad_car_salida like '%Ã‘%' then
            v_cad_car_salida := replace(v_cad_car_salida,'Ã‘','N');
            end if;
            -- Se encontró un carácter especial
            v_cad_car_salida := TRANSLATE(v_cad_car_salida,
                'áéíóúÁÉÍÓÚäëïöüÄËÏÖÜâêîôûÂÊÎÔÛàèìòùÀÈÌÒÙåÅÃãÕõñÑýÝçÇ' || CHR(38) || '´^`‘"',
                'aeiouAEIOUaeiouAEIOUaeiouAEIOUaeiouAEIOUaAAaoonNyYcCy      ');

             IF INSTR(v_cad_car_validos, SUBSTR(v_cad_car_salida, i, 1)) = 0 THEN
                 v_cad_car_salida := replace(v_cad_car_salida,SUBSTR(v_cad_car_salida, i, 1),' ');
             end if ;

        END IF;
    END LOOP;
     RETURN v_cad_car_salida;
    end if;
    -- No se encontraron caracteres especiales
    RETURN p_cad_car_entrada;
   end;
   -- Retorna los datos de una persona
   PROCEDURE lp_obt_dat_persona
   (
      p_cod_persona    IN ba_personas.cod_persona%TYPE,
      p_tip_documento  OUT sb_crc_vinculos_det.tip_documento%TYPE,
      p_nro_documento  OUT sb_crc_vinculos_det.nro_documento%TYPE,
      p_fec_nacimiento OUT sb_crc_vinculos_det.fec_nacimiento%TYPE,
      p_nombres        OUT sb_crc_vinculos_det.nombres%TYPE,
      p_apellidos      OUT sb_crc_vinculos_det.apellidos%TYPE
   ) IS

      v_tipo ba_personas.tipo%TYPE := null;
      v_nombres        sb_crc_vinculos_det.nombres%TYPE := null;
      v_apellidos      sb_crc_vinculos_det.apellidos%TYPE := null;

   BEGIN
      -- leo los datos generales de la persona
      SELECT decode(fue_obt_tip_doc_abreviatura(cod_tip_documento), 'DNI', 'CRC', 'PAS', 'CRC', 'SW',
                    'CRC', 'OTR', 'CRC', 'PJ', 'CRC', 'CIE', 'CRC','OJUD','CRC',--fieldesk-13353 nuevo tipo de documento insertado en ene-2022
                    fue_obt_tip_doc_abreviatura(cod_tip_documento)),
             decode(fue_obt_tip_doc_abreviatura(cod_tip_documento), 'CRP',
                    (SELECT TRIM(leading '0' FROM nro_documento) FROM dual), nro_documento) nro_documento,
             tipo
        INTO p_tip_documento, p_nro_documento, v_tipo
        FROM ba_personas a
       WHERE cod_persona = p_cod_persona;
      -- si es fisica leo sus nombres, apellidos y fecha de nacimiento
      IF v_tipo = 'F' THEN
         SELECT fec_nacimiento,
                pri_nombre || ' ' || seg_nombre,
                pri_apellido || ' ' || seg_apellido
           INTO p_fec_nacimiento, v_nombres, v_apellidos
           FROM ba_per_fisicas
          WHERE cod_persona = p_cod_persona;

           p_nombres   := lf_rem_car_especiales(v_nombres);
           p_apellidos := lf_rem_car_especiales(v_apellidos);
      ELSE
         -- si es juridica leo la razon social y su fecha de apertura
         SELECT NULL, raz_social, NULL
           INTO p_fec_nacimiento, v_nombres, v_apellidos
           FROM ba_per_juridicas
          WHERE cod_persona = p_cod_persona;

           p_nombres   := lf_rem_car_especiales(v_nombres);
           p_apellidos := lf_rem_car_especiales(v_apellidos);
      END IF;
   EXCEPTION
      WHEN OTHERS THEN
         p_tip_documento  := NULL;
         p_nro_documento  := NULL;
         p_fec_nacimiento := NULL;
         p_nombres        := NULL;
         p_apellidos      := NULL;

   END;

   -- Procedimiento de generacion de Archivo de Vinculos
   PROCEDURE lp_crc_ins_vinculos(rp_scvin sb_crc_vinculos_det%ROWTYPE) IS
      v_ins_registro VARCHAR2(1) := 'N';
   BEGIN
      IF v_cod_entidad = 6004 AND rp_scvin.cod_persona <> v_cod_per_bco_central THEN
         v_ins_registro := 'S';
      ELSIF rp_scvin.cod_persona NOT IN (v_cod_per_entidad, v_cod_per_bco_central) THEN
         v_ins_registro := 'S';
      ELSIF nvl(v_inc_ope_entidad, 'N') = 'S' AND rp_scvin.cod_persona = v_cod_per_entidad THEN
         v_ins_registro := 'S';
      ELSIF rp_scvin.tip_operacion = '183' /*Cheques Comprados del pais*/
       THEN
         v_ins_registro := 'S';
      END IF;

      IF v_ins_registro = 'S' THEN
         -- inserto los datos en sb_crc_vinculos_det
         INSERT INTO sb_crc_vinculos_det
            (fecha,
             nom_referencia,
             nro_formulario,
             cod_oficina,
             tip_operacion,
             cta_con_capital,
             nro_operacion,
             cod_mon_iso,
             tip_documento,
             nro_documento,
             fec_nacimiento,
             nombres,
             apellidos,
             tip_vinculo,
             per_vinculada,
             nro_registro,
             cod_modulo,
             cod_persona)
         VALUES
            (rp_scvin.fecha,
             rp_scvin.nom_referencia,
             rp_scvin.nro_formulario,
             nvl(fug_obt_pardinamico('COD_OFI_NO_HAB_BCP', NULL, NULL, NULL, rp_scvin.cod_oficina),
                 rp_scvin.cod_oficina),
             rp_scvin.tip_operacion,
             rp_scvin.cta_con_capital,
             rp_scvin.nro_operacion,
             rp_scvin.cod_mon_iso,
             rp_scvin.tip_documento,
             rp_scvin.nro_documento,
             rp_scvin.fec_nacimiento,
             rp_scvin.nombres,
             rp_scvin.apellidos,
             rp_scvin.tip_vinculo,
             rp_scvin.per_vinculada,
             rp_scvin.nro_registro,
             rp_scvin.cod_modulo,
             rp_scvin.cod_persona);
      ELSE
         v_nro_reg_vin := v_nro_reg_vin - 1;
      END IF;
   END;
   -- Modificacion con sb_personas_ref
   PROCEDURE pr_act_dat_cla_crc(p_fecha IN DATE) IS
      v_existe            VARCHAR2(1);
      v_rf_apellido       VARCHAR2(60);
      v_rf_nombre         VARCHAR2(60);
      v_tip_identificador VARCHAR2(3);
      v_nro_identificador VARCHAR2(15);
      v_fecha             DATE;
      v_contador          NUMBER(6) := 0;
      v_per_es_fisica     VARCHAR2(1);

      CURSOR c_personas IS
         SELECT a.tip_documento, a.nro_documento, a.apellidos, a.nombres, a.fec_nacimiento sigla_fecha, a.cod_persona,
                a.rowid registro
           FROM sb_crc_clasificaciones_det a
          WHERE a.fecha = p_fecha;

   BEGIN
      --ciclo principal del programa--
      BEGIN
         pre_ini_aplicacion;
         pae_cnf.g_cod_modulo := 1;
      END;
      FOR det IN c_personas LOOP
         v_contador := v_contador + 1;
         IF v_contador > 100 THEN
            COMMIT;
            v_contador := 0;
         END IF;
      END LOOP;
      COMMIT;
   EXCEPTION
      WHEN OTHERS THEN
         NULL;
   END;
   --

   -- Funcion para buscar el codigo de persona del banco.
   FUNCTION fu_obt_cod_per_bco(p_nro_cuenta ge_cuentas.nro_cuenta%TYPE) RETURN VARCHAR2 IS
      v_cod_persona ge_bancos.cod_persona%TYPE;
   BEGIN
      SELECT c.cod_persona
        INTO v_cod_persona
        FROM cc_cta_bancarias b, ge_bancos c
       WHERE b.cod_banco = c.cod_banco
         AND b.nro_cuenta = p_nro_cuenta;
      RETURN v_cod_persona;
   EXCEPTION
      WHEN OTHERS THEN
         RETURN NULL;
   END;

   -- Funcion para obtener numero de cuenta original de la operacion vencida
   FUNCTION lf_obt_nro_cta_ori_vencida(p_nro_cuenta ov_cta_vencidas.nro_cuenta%TYPE) RETURN VARCHAR2 IS
      v_nro_cta_origen ov_cta_vencidas.nro_cta_origen%TYPE;
   BEGIN
      SELECT v.nro_cta_origen
        INTO v_nro_cta_origen
        FROM ov_cta_vencidas v
       WHERE v.nro_cuenta = p_nro_cuenta;
      RETURN v_nro_cta_origen;
   EXCEPTION
     WHEN OTHERS THEN
        RETURN NULL;
   END;

   FUNCTION lf_obt_tip_entidad(p_cod_persona ba_personas.cod_persona%TYPE) RETURN VARCHAR2 IS
      v_entidad VARCHAR2(1) := 'N';
   BEGIN
      SELECT DISTINCT 'S'
        INTO v_entidad
        FROM ge_entes
       WHERE tipo = 'FI'
         AND cod_persona = p_cod_persona
      UNION
      SELECT DISTINCT 'S'
        FROM ge_bancos
       WHERE cod_persona = p_cod_persona;

      RETURN v_entidad;
   EXCEPTION
      WHEN no_data_found THEN
         RETURN 'N';
      WHEN too_many_rows THEN
         RETURN 'S';
      WHEN OTHERS THEN
         RETURN 'N';
   END;
       ---proceso de insercion del tip_vinculo 9 de la vta cartera
   PROCEDURE lp_crc_gen_vin_vta_cartera IS

      CURSOR c_vinculos IS
       SELECT p.cod_persona cod_persona, 'P' relacion, h.cod_modulo,h.cod_modalidad, h.nom_comprador,
               h.ruc_comprador nro_documento, 'RUC' tip_documento, o.nro_operacion nro_cuenta
          FROM ge_sal_inv_vta_cartera_his h, ba_personas p,sb_crc_operaciones_det o
         WHERE h.estado in ( 'V', 'C' )
           AND h.ope_recaptados = 'N'
           AND h.fec_venta = v_fec_fin
           and h.nro_cuenta = NVL(SUBSTR(o.NRO_OPERACION,1,INSTR(o.NRO_OPERACION,'#')-1),o.NRO_OPERACION)
           AND nvl(h.sal_deu_cta_actual, h.mto_deu_mon_cuenta) > 0
           AND h.ruc_comprador = p.nro_documento(+);

        rg_scvin sb_crc_vinculos_det%ROWTYPE;
        rp_gclog sb_log_crc%ROWTYPE;
        v_rub_con_capital sb_crc_operaciones_det.cta_con_cap_original%TYPE;
        v_cod_modulo ta_cta_tarjetas.cod_modulo%type;
        v_cod_modalidad ta_cta_tarjetas.cod_modalidad%type;
        v_fec_sal_ant sb_crc_saldos_det.fecha%type;

    BEGIN
      --descomentar si se va a reprocesar de forma independiente
     /* begin
        delete sb_crc_vinculos_det v
        where v.fecha = v_fec_fin
        and v.tip_vinculo = 9;
          commit;
        end;*/

      begin
        select max(v.nro_registro)
        into v_nro_reg_vin
        from sb_crc_vinculos_det v
        where v.fecha = v_fec_fin;

        if v_nro_reg_vin is null then
          v_nro_reg_vin := 0;
          end if;

        exception
          when others then
            v_nro_reg_vin := 0;
        end;

        begin
          select s.fecha
          into v_fec_sal_ant
           from sb_crc_saldos_det s
           where s.fecha = trunc(to_date('01' || to_char(add_months(v_fec_fin, -0), 'mmyyyy'),'ddmmyyyy'),'MM')-1
           and rownum = 1;

        if v_fec_sal_ant is null then
          select s.fecha
          into v_fec_sal_ant
           from sb_crc_saldos_det s
           where s.fecha = trunc(to_date('01' || to_char(add_months(v_fec_fin, -1), 'mmyyyy'),'ddmmyyyy'),'MM')-1
           and rownum = 1;
          end if;

        exception
          when others then
            v_fec_sal_ant := null;
        end;

      FOR dt IN c_vinculos LOOP
         rg_scvin                := NULL;
         -- datos de la persona vinculada o relacionada
         rg_scvin.tip_documento := dt.tip_documento;
         rg_scvin.nro_documento := dt.nro_documento;
         rg_scvin.nombres       := dt.nom_comprador;

         IF rg_scvin.tip_documento IS NULL OR rg_scvin.nro_documento IS NULL THEN
            rp_gclog.fecha          := v_fec_fin;
            rp_gclog.nom_referencia := 'VINCULOS';
            rp_gclog.usu_insercion  := substr(USER, 1, 10);
            rp_gclog.fec_insercion  := SYSDATE;
            rp_gclog.mensaje        := 'Favor verificar los datos de la persona: ' || dt.cod_persona ||
                                       '.Tipo vinculo:'||dt.relacion||'. Datos no encontrados o erroneos en tipo de documento o nro. de documento.';
            rp_gclog.nro_registro   := dt.nro_cuenta;
            lp_log_crc(rp_gclog);
         ELSE
            rg_scvin.nom_referencia := 'VINCULOS';
            rg_scvin.nro_formulario := '002';
            rg_scvin.fecha          := v_fec_fin;
            -- Datos de la operacion
            IF dt.cod_modulo <> 15 or (dt.cod_modulo = 15 and dt.cod_modalidad = 154) THEN
               rg_scvin.nro_operacion   := dt.nro_cuenta;
                BEGIN

                  SELECT o.cod_oficina, o.tip_operacion, o.cta_con_cap_original, o.cod_moneda
                    INTO rg_scvin.cod_oficina, rg_scvin.tip_operacion, v_rub_con_capital, rg_scvin.cod_mon_iso
                    FROM sb_crc_operaciones_det o
                   WHERE o.nro_operacion = rg_scvin.nro_operacion
                     AND substr(o.cta_con_cap_original, 1, 1) = 1
                     AND rownum = 1;

            EXCEPTION
              WHEN OTHERS THEN
                BEGIN
                  SELECT o.cod_oficina, o.tip_operacion, o.cta_con_cap_original, o.cod_moneda, o.nro_operacion
                    INTO rg_scvin.cod_oficina, rg_scvin.tip_operacion, v_rub_con_capital, rg_scvin.cod_mon_iso, rg_scvin.nro_operacion
                    FROM sb_crc_operaciones_det o
                   WHERE o.nro_operacion = dt.nro_cuenta
                     AND rownum = 1;
                EXCEPTION
                  WHEN OTHERS THEN
                    NULL;
                END;
            END;
            ELSE
               rg_scvin.nro_operacion := lf_obt_nro_cta_ori_vencida(dt.nro_cuenta);
               --se ajustan valores de ope vencidas a la operacion original reportada
                ---operaciones de sobregiro

                  BEGIN
                    if dt.cod_modalidad = 153 then
                    BEGIN
                      SELECT
                          cod_oficina,tip_operacion,rubro_capital,cod_moneda
                      INTO
                          rg_scvin.cod_oficina,rg_scvin.tip_operacion,v_rub_con_capital,rg_scvin.cod_mon_iso
                      FROM (

                          SELECT
                              o.cod_oficina,o.tip_operacion,o.rub_con_capital AS rubro_capital,o.con_mon_iso AS cod_moneda,
                              1 AS prioridad
                          FROM sb_crc_saldos_det o
                          WHERE o.nro_operacion = rg_scvin.nro_operacion
                            AND o.tip_operacion = substr(v_ope_sob_linea1,instr(v_ope_sob_linea1,o.tip_operacion),3)
                            AND SUBSTR(o.rub_con_capital, 1, 1) = '1'
                            AND o.fecha = v_fec_sal_ant

                          UNION ALL

                          SELECT
                              o.cod_oficina,o.tip_operacion,o.rub_con_capital,o.con_mon_iso,
                              2 AS prioridad
                          FROM sb_crc_saldos_det o
                          WHERE o.nro_operacion = rg_scvin.nro_operacion
                            AND o.tip_operacion = substr(v_ope_sob_linea2,instr(v_ope_sob_linea2,o.tip_operacion),3)
                            AND SUBSTR(o.rub_con_capital, 1, 1) = '1'
                            AND o.fecha = v_fec_sal_ant

                          UNION ALL

                          SELECT
                              o.cod_oficina,o.tip_operacion,o.cta_con_cap_original,o.cod_moneda,
                              3 AS prioridad
                          FROM sb_crc_operaciones_det o
                          WHERE o.nro_operacion = rg_scvin.nro_operacion
                            AND o.tip_operacion = substr(v_ope_sob_linea1,instr(v_ope_sob_linea1,o.tip_operacion),3)
                            AND SUBSTR(o.cta_con_cap_original, 1, 1) = '1'

                          UNION ALL

                          SELECT
                              o.cod_oficina,o.tip_operacion,o.cta_con_cap_original,o.cod_moneda,
                              4 AS prioridad
                          FROM sb_crc_operaciones_det o
                          WHERE o.nro_operacion = rg_scvin.nro_operacion
                            AND o.tip_operacion = substr(v_ope_sob_linea2,instr(v_ope_sob_linea2,o.tip_operacion),3)
                            AND SUBSTR(o.cta_con_cap_original, 1, 1) = '1'
                      )
                      ORDER BY prioridad ASC
                      FETCH FIRST 1 ROW ONLY;

                  EXCEPTION
                      WHEN NO_DATA_FOUND THEN
                          rg_scvin.cod_oficina := null;
                          rg_scvin.tip_operacion := null;
                          v_rub_con_capital := null;
                          rg_scvin.cod_mon_iso := null;
                  END;

              else

              --verifica si es una TC de adm de Ueno
              begin
                     select t.cod_modulo,t.cod_modalidad
                      into v_cod_modulo, v_cod_modalidad
                     from ta_cta_tarjetas t
                     where t.nro_cuenta = rg_scvin.nro_operacion;

                   exception
                     when no_data_found then
                      v_cod_modulo := null;
                      v_cod_modalidad := null ;
                   end;

            if nvl(fug_obt_pardinamico('MAD_TAR_CRE_UENO',v_cod_modulo, v_cod_modalidad),'N') = 'S' then

                  SELECT o.cod_oficina, o.tip_operacion, o.cta_con_cap_original, o.cod_moneda
                    INTO rg_scvin.cod_oficina, rg_scvin.tip_operacion, v_rub_con_capital, rg_scvin.cod_mon_iso
                    FROM sb_crc_operaciones_det o
                   WHERE o.nro_operacion = rg_scvin.nro_operacion
                     AND substr(o.cta_con_cap_original, 1, 1) = 1
                     AND rownum = 1;
             else
                  SELECT o.nro_operacion,o.cod_oficina, o.tip_operacion, o.cta_con_cap_original, o.cod_moneda
                    INTO rg_scvin.nro_operacion,rg_scvin.cod_oficina, rg_scvin.tip_operacion, v_rub_con_capital, rg_scvin.cod_mon_iso
                    FROM sb_crc_operaciones_det o,ta_tarjetas t
                   WHERE t.nro_cuenta = rg_scvin.nro_operacion
                     and o.nro_operacion = t.nro_tarjeta
                     AND substr(o.cta_con_cap_original, 1, 1) = 1
                     AND rownum = 1;
             end if;
             end if;
            EXCEPTION
              WHEN OTHERS THEN
                BEGIN
                  SELECT o.cod_oficina, o.tip_operacion, o.cta_con_cap_original, o.cod_moneda, o.nro_operacion
                    INTO rg_scvin.cod_oficina, rg_scvin.tip_operacion, v_rub_con_capital, rg_scvin.cod_mon_iso, rg_scvin.nro_operacion
                    FROM sb_crc_operaciones_det o
                   WHERE o.nro_operacion = dt.nro_cuenta
                     AND rownum = 1;
                EXCEPTION
                  WHEN OTHERS THEN
                    NULL;
                END;
            END;
            END IF;


            rg_scvin.cta_con_capital := fue_obt_val_max_refcodes('COD_RUB_VTA_CARTERA', rg_scvin.cod_mon_iso);
            IF rg_scvin.cta_con_capital IS NULL THEN
               rg_scvin.cta_con_capital := v_rub_con_capital;
            END IF;
            --cod_modulo
            rg_scvin.cod_modulo   := dt.cod_modulo;
            --
            rg_scvin.cod_persona     := dt.cod_persona;
            -- tipo de vinculo
            rg_scvin.tip_vinculo     := 9;
            -- relacion con la entidad
            IF fu_cli_rel_entidad(dt.cod_persona) THEN
               rg_scvin.per_vinculada := 'S';
            ELSE
               rg_scvin.per_vinculada := 'N';
            END IF;
            IF rg_scvin.tip_vinculo IS NOT NULL THEN
               v_nro_reg_vin         := v_nro_reg_vin + 1;
               rg_scvin.nro_registro := v_nro_reg_vin;
            -- Inserto el registro en vinculos
               lp_crc_ins_vinculos(rg_scvin);
              END IF;
         END IF;
       END LOOP;
    END;

   FUNCTION fu_es_unipersonal(p_nro_documento sb_crc_vinculos_det.nro_documento%type) RETURN VARCHAR2 IS

    v_nro_documento   VARCHAR2(100);
    v_es_unipersonal VARCHAR2(2);
    v_dig_verificador     NUMBER;

   BEGIN
     -- Pre-calcula el prefijo del documento
    v_dig_verificador := INSTR(p_nro_documento, '-');
    IF v_dig_verificador > 0 THEN
        v_nro_documento := SUBSTR(p_nro_documento, 1, v_dig_verificador - 1);
    ELSE
        v_nro_documento := p_nro_documento;
    END IF;

    SELECT
        CASE
            -- Usamos MAX para verificar la existencia de cada condición
            WHEN MAX(CASE WHEN cod_tip_documento = 6 THEN 1 ELSE 0 END) = 1
             AND MAX(CASE WHEN cod_tip_documento != 6 THEN 1 ELSE 0 END) = 1
            THEN 'S'
            ELSE 'N'
        END
    INTO v_es_unipersonal
    FROM BA_PERSONAS p
    WHERE
        p.nro_documento LIKE v_nro_documento || '%'
        --AND p.est_verificacion = 'V'
        ;

      RETURN v_es_unipersonal;
   EXCEPTION
      when no_data_found then
      RETURN 'N';
      WHEN OTHERS THEN
      RETURN 'N';
   END;

   -- NOR-764 CDA-D: cuenta interna de un ISIN; ante ISIN repetido prioriza no anulados y el mas reciente
   FUNCTION lf_obt_cta_isin(p_cod_isin ah_cta_certificados.cod_isin%TYPE) RETURN ah_cta_certificados.nro_cuenta%TYPE IS
      v_nro_cuenta ah_cta_certificados.nro_cuenta%TYPE;
   BEGIN
      SELECT nro_cuenta
        INTO v_nro_cuenta
        FROM (SELECT h.nro_cuenta
                FROM ah_cta_certificados h
               WHERE h.cod_isin = p_cod_isin
                 AND h.cod_modalidad = 34
               ORDER BY CASE WHEN h.estado IN ('A', 'X') THEN 1 ELSE 0 END, h.fec_apertura DESC, h.nro_cuenta DESC)
       WHERE ROWNUM = 1;
      RETURN v_nro_cuenta;
   EXCEPTION
      WHEN no_data_found THEN
         RETURN NULL;
   END;

   -- procedimiento local para generar
   PROCEDURE lp_crc_gen_vinculos(p_cod_oficina     sb_crc_vinculos_det.cod_oficina%TYPE,
                                 p_nro_operacion   sb_crc_vinculos_det.nro_operacion%TYPE,
                                 p_tip_operacion   sb_crc_vinculos_det.tip_operacion%TYPE,
                                 p_cod_modulo      sb_crc_operaciones_det.cod_modulo%type,
                                 p_cta_con_capital sb_crc_vinculos_det.cta_con_capital%TYPE,
                                 p_cod_mon_iso     sb_crc_vinculos_det.cod_mon_iso%TYPE,
                                 p_cod_persona     sb_crc_vinculos_det.cod_persona%TYPE DEFAULT NULL) IS

      v_cta_isin ah_cta_certificados.nro_cuenta%TYPE := lf_obt_cta_isin(p_nro_operacion);

      CURSOR c_vinculos IS
         SELECT cod_persona, relacion, cod_modulo
           FROM ge_cta_clientes a
          WHERE nro_cuenta = NVL(v_cta_isin, fus_obt_cta_operacion(p_nro_operacion, p_cod_modulo))
            AND relacion = 'P'
            AND (a.cod_persona = p_cod_persona OR p_cod_persona IS NULL)
            AND p_tip_operacion <> '183'
         UNION
         SELECT cod_persona, relacion, cod_modulo
           FROM ge_cta_clientes a
          WHERE nro_cuenta = pae_uti.fu_obt_valor(NVL(v_cta_isin, fus_obt_cta_operacion(p_nro_operacion, p_cod_modulo)), 1)
            AND relacion = 'P'
            AND (a.cod_persona = p_cod_persona OR p_cod_persona IS NULL)
            AND (p_tip_operacion <> '183' or (a.cod_modalidad = '660' and p_tip_operacion = '183'))
         UNION
         SELECT cod_persona, a.relacion, a.cod_modulo
           FROM ge_cta_clientes a, ge_modalidades mo
          WHERE nro_cuenta = pae_uti.fu_obt_valor(NVL(v_cta_isin, fus_obt_cta_operacion(p_nro_operacion, p_cod_modulo)), 1)
            AND relacion NOT IN ('P', 'A') -- adicionales no se envian
           AND ((mo.cod_modulo = a.cod_modulo AND mo.cod_modalidad = a.cod_modalidad AND mo.tipo <> 'P' AND
               relacion IN ('C', 'G')) OR -- enviar firmantes
               (mo.cod_modulo = a.cod_modulo AND mo.cod_modalidad = a.cod_modalidad AND mo.tipo = 'P' AND
               relacion NOT IN ('C', 'G'))) -- no enviar codeudores de cuentas pasivas.
            and p_tip_operacion not in (substr(v_ope_sob_linea1,instr(v_ope_sob_linea1,p_tip_operacion),3),
                                        substr(v_ope_sob_linea2,instr(v_ope_sob_linea2,p_tip_operacion),3))
            AND (a.cod_persona = p_cod_persona OR p_cod_persona is null)
            AND NOT EXISTS (SELECT 1
                   FROM ba_vinculos v, ge_cta_clientes g
                  WHERE v.cod_per_vinculo = a.cod_persona
                    AND v.cod_per_vinculo = g.cod_persona
                    AND g.nro_cuenta = pae_uti.fu_obt_valor(NVL(v_cta_isin, fus_obt_cta_operacion(p_nro_operacion, p_cod_modulo)), 1)
                    AND g.relacion = 'P' --descomentado de nuevo fieldesk-3134
                    AND tipo = 'E')
         UNION
         -- Conyuges
         SELECT v.cod_per_vinculo, v.tipo relacion, c.cod_modulo
           FROM ba_vinculos v, ge_cta_clientes c, ge_modalidades mo
          WHERE v.cod_persona = c.cod_persona
            AND c.cod_modulo = mo.cod_modulo
            AND c.cod_modalidad = mo.cod_modalidad
            AND mo.tipo <> 'P' -- no enviar cuentas pasivas.
            AND c.nro_cuenta = pae_uti.fu_obt_valor(fus_obt_cta_operacion(p_nro_operacion, p_cod_modulo), 1)
            AND v.tipo = 'E'
            AND (c.cod_persona = p_cod_persona OR p_cod_persona IS NULL OR v.cod_per_vinculo = p_cod_persona)
            AND NOT EXISTS (SELECT 1
                   FROM ge_cta_clientes s
                  WHERE s.nro_cuenta = c.nro_cuenta
                    AND s.cod_persona = v.cod_per_vinculo
                -- AND s.relacion = 'P'--comentado de nuvo para dejar como estana orignalmente fieldesk-3134
                 )
            AND (p_tip_operacion <> '183' or (p_tip_operacion = '183' and c.cod_modalidad = '660'))
            AND v_inc_conyuges = 'S' --parametro cambiado a S, estaba en N
         UNION
         -- Emisores Descuento de cheques
         SELECT DISTINCT e.cod_persona, 'L' relacion, f.cod_modulo
           FROM ge_che_custodias a, pr_rel_chq_lib b, pr_chq_libradores c, ba_personas e, pr_cta_prestamos f
          WHERE a.nro_referencia = pae_uti.fu_obt_valor(p_nro_operacion, 1)--#03 Debe enviarse el parametro en 1 para que recupere el nro de operacion correcto - Eduardo Nu?ez 22-04-2021
            AND a.nro_cheque = b.nro_cheque
            AND a.cod_banco = b.cod_banco
            AND a.cta_libradora = b.cta_libradora
            AND c.nro_documento = b.nro_documento
            AND a.nro_cuota = pae_uti.fu_obt_valor(p_nro_operacion, 2)
            AND c.cod_tip_documento = b.cod_tip_documento
            AND e.nro_documento = c.nro_documento
            AND e.cod_tip_documento = c.cod_tip_documento
            AND b.nro_documento = e.nro_documento
            AND P_COD_MODULO = 6
            AND b.cod_tip_documento = e.cod_tip_documento
            AND f.nro_cuenta = a.nro_referencia
            AND a.estado IN ('A', 'B', 'C')
            AND NOT EXISTS (SELECT 1
                   FROM ge_cta_clientes ct
                  WHERE ct.nro_cuenta = f.nro_cuenta
                    AND e.cod_persona = ct.cod_persona
                    AND relacion = 'P')
            AND nvl(fup_obt_tip_descuento(f.cod_modalidad), 'X') IN ('D', 'C')
            AND v_inc_emisores = 'S'
            AND (e.cod_persona = p_cod_persona OR p_cod_persona IS NULL)
         UNION
       ---Emisores de cheques devueltos(660)
       SELECT DISTINCT z.cod_persona, 'L' relacion, 6
         FROM (SELECT substr(descripcion, 5, instr(descripcion, 'CTA') - 5) nro_cheque,
                      substr(descripcion, instr(descripcion, 'CTA') + 4, length(descripcion)) nro_cuenta,
                      nro_cuenta nro_cuenta_ori
                 FROM pr_cta_prestamos
                WHERE cod_modalidad = 660
                  AND est_batch <> 'N') p,
              ge_che_custodias t,
              pr_rel_chq_lib x,
              pr_chq_libradores y,
              ba_personas z
        WHERE p.nro_cuenta = t.nro_referencia
          AND p.nro_cheque = t.nro_cheque
          AND x.cod_banco = t.cod_banco
          AND x.nro_cheque = t.nro_cheque
          AND x.cta_libradora = t.cta_libradora
          and p_cod_modulo = 6
          AND t.estado = 'B' -- devuelto
          AND y.nro_documento = x.nro_documento
          AND y.cod_tip_documento = x.cod_tip_documento
          AND z.nro_documento = x.nro_documento
          AND z.cod_tip_documento = x.cod_tip_documento
          AND v_inc_emisores = 'S'
          AND p.nro_cuenta_ori = pae_uti.fu_obt_valor(fus_obt_cta_operacion(p_nro_operacion, p_cod_modulo), 1)
         UNION
         -- Emisores Descuento de documentos
         SELECT distinct p.cod_persona, 'L' relacion, pr.cod_modulo
           FROM pr_documentos d, ba_personas p, pr_cta_prestamos pr
          WHERE d.estado = 'C'
            AND p.cod_tip_documento = d.cod_tip_documento
            AND p.nro_documento = d.nro_documento
            and p_cod_modulo = 6
            AND d.nro_cuota = pae_uti.fu_obt_valor(p_nro_operacion, 2)
            --AND d.nro_referencia = pae_uti.fu_obt_valor(p_nro_operacion, 2)
            AND d.nro_referencia = pae_uti.fu_obt_valor(p_nro_operacion, 1)--Se ajusta para que busque nro de cuenta estaba trayendo nro de cuota
            AND d.nro_referencia = pr.nro_cuenta
            AND pr.est_batch <> 'N' -- No canceladas
            AND nvl(fup_obt_tip_descuento(pr.cod_modalidad), 'X') IN ('D', 'C')
            AND NOT EXISTS (SELECT 1
                             FROM ge_cta_clientes ct
                            WHERE ct.nro_cuenta = pr.nro_cuenta
                              AND p.cod_persona = ct.cod_persona
                              AND relacion = 'P')
            --AND pr.est_batch <> 'N' -- No canceladas--se comenta por duplicacion de coondicion
            AND pr.nro_cuenta = d.nro_referencia
            AND nvl(fup_obt_tip_descuento(pr.cod_modalidad), 'X') IN ('D', 'C')
            AND v_inc_emisores = 'S'
            AND (p.cod_persona = p_cod_persona OR p_cod_persona IS NULL)
         UNION --- por cada cheque comprado del pais 183 se informa con el Titular de la Entidad
         SELECT DISTINCT  v_cod_per_entidad, 'P', 7
           FROM cc_che_enviados pr
          WHERE pr.nro_cheque = pae_uti.fu_obt_valor(p_nro_operacion, 2)
            AND P_COD_MODULO in (6,3)---= 6
            AND p_tip_operacion = '183'
          UNION
         SELECT DISTINCT fue_obt_cod_persona_doc(g.cod_tip_documento, g.nro_documento), 'P', 7
           FROM cc_che_enviados pr, lc_che_com_libradores g
          WHERE pr.nro_cheque = pae_uti.fu_obt_valor(p_nro_operacion, 2)
            AND p_tip_operacion = '183'
            and p_cod_modulo = 6
            AND pr.nro_cheque = g.nro_cheque
            AND pr.cod_banco = g.cod_banco
       UNION -- compra de cartera
         SELECT s.cod_persona, 'X', a.cod_modulo
           FROM pr_cta_prestamos a, ge_cta_dat_adicionales b, ge_entes s
          WHERE a.nro_cuenta = b.nro_cuenta
            AND a.nro_cuenta = pae_uti.fu_obt_valor(fus_obt_cta_operacion(p_nro_operacion, p_cod_modulo),1)
            AND s.descripcion = b.val_parametro
            AND P_COD_MODULO = 6
            AND s.tipo = 'CC'
            AND b.parametro = 'PRE_COD_ENT_COM_CARTERA'
        /* UNION
         SELECT b.cod_persona, 'V', 6
           FROM ge_cta_dat_adicionales a, ge_entes b
          WHERE parametro = 'ENT_ADM_CARTERA'
            AND b.descripcion = a.val_parametro
            AND b.tipo = 'AC'
            AND a.nro_cuenta = pae_uti.fu_obt_valor(fus_obt_cta_operacion(p_nro_operacion, p_cod_modulo), 1)*/
            ;

      rg_scvin      sb_crc_vinculos_det%ROWTYPE;
      rp_slcrc      sb_log_crc%ROWTYPE;
      v_cod_persona ge_bancos.cod_persona%TYPE;
      v_val_parametro ge_cta_dat_adicionales.val_parametro%TYPE;
      v_cta_ruc       number:=0;
      v_con_codeudor  varchar2(1) := 'N'; --fieldesk-3134
   BEGIN
      FOR dt IN c_vinculos LOOP
         rg_scvin := NULL;
         IF dt.cod_persona = v_cod_per_entidad AND dt.cod_modulo = 4 THEN
            --para cuentas bancarias
            v_cod_persona := nvl(fu_obt_cod_per_bco(fus_obt_cta_operacion(p_nro_operacion, p_cod_modulo)), dt.cod_persona);
         ELSE
            v_cod_persona := dt.cod_persona;
         END IF;
         -- datos de la persona vinculada o relacionada
         lp_obt_dat_persona(v_cod_persona,
                            rg_scvin.tip_documento,
                            rg_scvin.nro_documento,
                            rg_scvin.fec_nacimiento,
                            rg_scvin.nombres,
                            rg_scvin.apellidos);
         --v_nro_reg_vin := 0;
         IF rg_scvin.tip_documento IS NULL OR rg_scvin.nro_documento IS NULL THEN
            rp_slcrc.fecha          := v_fec_fin;--to_date('03/10/2021','dd/mm/yyyy');--v_fec_fin;
            rp_slcrc.nom_referencia := 'VINCULOS';
            rp_slcrc.usu_insercion  := substr(USER, 1, 10);
            rp_slcrc.fec_insercion  := sysdate;--to_date('03/10/2021','dd/mm/yyyy');--SYSDATE;
            rp_slcrc.mensaje        := 'Favor verificar los datos de la persona: ' || v_cod_persona || '.Tipo vinculo:' ||
                                       dt.relacion ||
                                       '. Datos no encontrados o erroneos en tipo de documento o nro. de documento.';
            rp_slcrc.nro_registro   := rg_scvin.nro_documento;
            lp_log_crc(rp_slcrc);
         ELSE
            rg_scvin.nom_referencia := 'VINCULOS';
            rg_scvin.nro_formulario := '002';
            rg_scvin.fecha          := v_fec_fin;--to_date('03/10/2021','dd/mm/yyyy');--v_fec_fin;
            -- Datos de la operacion
            rg_scvin.cod_oficina     := p_cod_oficina;
            rg_scvin.tip_operacion   := p_tip_operacion;
            rg_scvin.cta_con_capital := p_cta_con_capital;
            rg_scvin.nro_operacion   := p_nro_operacion;
            rg_scvin.cod_mon_iso     := p_cod_mon_iso;
            rg_scvin.cod_modulo      := dt.cod_modulo;
            rg_scvin.cod_persona     := v_cod_persona;
            -- tipo de vinculo
            IF dt.relacion = 'P' THEN
               IF fug_obt_paradicional(fus_obt_cta_operacion(p_nro_operacion, p_cod_modulo), 'EXO_ENCAJES') = 'S' THEN
                  rg_scvin.tip_vinculo := 101;
               ELSE
                  rg_scvin.tip_vinculo := 1;
               END IF;
            ELSIF dt.relacion in ('Y', 'O') and lf_obt_tip_persona(v_cod_persona) = 'F' then
              --verifica si corresponde a una cuenta de una empresa de ser asi, vinculo es 3
              select count(*)
                into v_cta_ruc
                from ge_cta_clientes c, ba_personas p
               where c.nro_cuenta = (select k.nro_cuenta
                                       from ge_cta_clientes k
                                      where k.cod_persona = v_cod_persona
                                        and k.nro_cuenta  = pae_uti.FU_OBT_VALOR (rg_scvin.nro_operacion,1)
                                        and k.relacion!='P'
                                        and rownum = 1)
                 and c.relacion = 'P'
                 and c.cod_persona = p.cod_persona
                 and p.tipo='J';
              if v_cta_ruc!=0 then
                rg_scvin.tip_vinculo := 3;
              else
                rg_scvin.tip_vinculo := 1 ;
              end if;
            ELSIF dt.relacion IN ('Y', 'O', 'R', 'T') THEN
               rg_scvin.tip_vinculo := 3;
            ELSIF dt.relacion = 'E' THEN
               rg_scvin.tip_vinculo := 7;
            ELSIF dt.relacion = 'X' THEN
             BEGIN
               SELECT b.val_parametro
                 INTO v_val_parametro
                 FROM pr_cta_prestamos a, ge_cta_dat_adicionales b
                WHERE a.nro_cuenta = b.nro_cuenta
                  AND a.nro_cuenta = pae_uti.fu_obt_valor(fus_obt_cta_operacion(p_nro_operacion, p_cod_modulo), 1)
                  AND b.parametro = 'PRE_COM_RECURSO';
               IF nvl(v_val_parametro,'N') = 'S' THEN
                  rg_scvin.tip_vinculo := 10;
               ELSE
                  rg_scvin.tip_vinculo := 11;
               END IF;
             EXCEPTION WHEN NO_DATA_FOUND THEN
                  rg_scvin.tip_vinculo := NULL;
             END;

            ELSIF dt.relacion = 'V' AND lf_obt_tip_entidad(dt.cod_persona) = 'N' THEN
               rg_scvin.tip_vinculo := 9;
            ELSIF dt.relacion = 'C' THEN
               --CONTTROL NUEVO PARA CONYUGE SIN MARCA (v_inc_conyuges = 'N')
               begin --fieldesk-3134
                 select 'S'
                   INTO v_con_codeudor
                   from pr_cta_garantias g
                  where g.nro_garantia = dt.cod_persona
                  --and g.nro_cuenta = p_nro_operacion Ajuste para fieldesk-3134
                  and g.nro_cuenta = pae_uti.FU_OBT_VALOR(p_nro_operacion, 1)
                    and cod_garantia = 19;
               exception
                 when no_Data_found then
                   v_con_codeudor := 'N';
                 when others then
                   v_con_codeudor := 'N';
               end;
               -- si es garantia conyuge informar como tal fieldesk-3134
               if v_con_codeudor = 'S' then
                 rg_scvin.tip_vinculo := 7;
               else
                 rg_scvin.tip_vinculo := 2;
               end if;
            ELSIF dt.relacion = 'L' THEN
               rg_scvin.tip_vinculo := 6;
            ELSE
               rg_scvin.tip_vinculo := 4;
            END IF;

            IF fu_es_unipersonal(rg_scvin.nro_documento) = 'S' THEN
               if rg_scvin.tip_documento = 'RUC' and rg_scvin.tip_vinculo = 1  then

                  rg_scvin.tip_documento := 'CI';
                  rg_scvin.nro_documento := substr(rg_scvin.nro_documento,1,instr(rg_scvin.nro_documento,'-')-1);

               elsif rg_scvin.tip_documento != 'RUC' and rg_scvin.tip_vinculo = 3 then

                 rg_scvin.tip_vinculo := 1;

               end if;
              END IF;
            ---->

            -- relacion con la entidad
            IF fu_cli_rel_entidad(dt.cod_persona) THEN
               rg_scvin.per_vinculada := 'S';
            ELSE
               rg_scvin.per_vinculada := 'N';
            END IF;
            --
            --utilizad para correr en fecha distinta no eliminar solo comentar.
            /*select NVL(max(l.nro_registro),1)
               into v_nro_reg_vin
               from sb_crc_vinculos_det l
              where l.fecha = '01/02/2022';*/

            v_nro_reg_vin         := nvl(v_nro_reg_vin, 0) + 1;
            rg_scvin.nro_registro := v_nro_reg_vin;
            -- Inserto el registro en vinculos
            lp_crc_ins_vinculos(rg_scvin);
         END IF;
      END LOOP;
   END;

   PROCEDURE pr_crc_gen_datos(p_tip_periodo IN VARCHAR2 DEFAULT 'D') IS
       v_inc_cta_basica varchar2(1) := fug_obt_pardinamico( 'INC_MOV_CTA_BAS_CI');
   BEGIN
      pag_cal.pr_obt_dat_calendar(1);
      v_fec_actual := pag_cal.fu_obt_fec_actual(1);
      v_fec_inicio := pag_cal.fu_obt_fec_actual(1);
      v_fec_fin    := pag_cal.fu_obt_fec_actual(1);
      IF p_tip_periodo = 'Q' THEN
         IF to_number(to_char(v_fec_actual, 'DD')) > 15 THEN
            -- Si la fecha de proceso es mayor a 15 tomar la primera quincena para procesar del 1 al 15
            v_fec_inicio := to_date('01' || to_char(v_fec_actual, 'mmyyyy'), 'ddmmyyyy');
            v_fec_fin    := to_date('15' || to_char(v_fec_actual, 'mmyyyy'), 'ddmmyyyy');
         ELSE
            -- Si la fecha de proceso es menor a 15 tomar la segunda quincena para procesar del 16
            -- al ultimo dia del mes anterior a la fecha de proceso.
            v_fec_inicio := to_date('16' || to_char(add_months(v_fec_actual, -1), 'mmyyyy'), 'ddmmyyyy');
            v_fec_fin    := last_day(v_fec_inicio);
         END IF;
      ELSIF p_tip_periodo = 'M' THEN
         v_fec_inicio := pag_cal.g_pri_dia_mes;
         v_fec_fin    :=pag_cal.g_ult_dia_mes;
      END IF;
      v_fec_ini_ant := pag_cal.fu_obt_fec_ant_hab(v_fec_inicio, NULL, 1);
      v_fec_fin_ant := pag_cal.fu_obt_fec_ant_hab(v_fec_fin, NULL, 1);
      v_fec_ult_mes := pag_cal.g_ult_dia_mes_habil;
      --
      DELETE sb_crc_operaciones_det
       WHERE fecha = v_fec_fin;
      DELETE sb_crc_operaciones
       WHERE fec_periodo = v_fec_fin;
      DELETE sb_crc_ope_no_enviados
       WHERE fecha = v_fec_actual;
      DELETE sb_crc_vinculos_det
       WHERE fecha = v_fec_fin;
      DELETE sb_crc_vinculos
       WHERE fec_periodo = v_fec_fin;
      DELETE sb_log_crc
       WHERE nom_referencia IN ('OPERACION','VINCULOS')
         AND fecha = v_fec_fin;
      COMMIT;
      v_nro_registro := 0;
      v_nro_reg_vin  := 0;
      -- Genero los datos de los detalles.
          pr_crc_gen_prestamos;
          pr_crc_gen_sobregiros;
          pr_crc_gen_tarjetas;
          pr_crc_gen_comex;
          pr_crc_gen_fianzas;
          pr_crc_gen_mes_dinero;
          pr_crc_gen_ope_vencidas;
          pr_crc_gen_pasivas;
      IF v_fec_inicio = v_fec_ult_mes and fu_pue_env_bcp(183) = 'S' THEN
         pr_crc_gen_che_comprados;
      END IF;
       if nvl(v_inc_cta_basica, 'N') = 'S' then
         pr_crc_gen_cta_basica;
      end if;
         pr_crc_gen_pignorados;
         pr_crc_gen_rub_diversos;
         pr_crc_gen_pasivas_compl;
         lp_crc_gen_vin_vta_cartera;
         pr_crc_val_datos;
      -- totalizo las tablas de detalles en las cabeceras respectivas.
      lp_act_tot_registro(v_fec_fin, 'SB_CRC_OPERACIONES');

   END;

   /* Obtener la categoria de prevision de clientes para categoria 1(Uno)*/
   FUNCTION lf_obt_cat_prevision(p_cod_persona IN ge_cla_operaciones.cod_persona%TYPE, p_tip_proceso varchar2) RETURN NUMBER AS

      v_cat_riesgo ge_cla_operaciones.cat_automatica%TYPE;
   BEGIN
      --Verifico las operaciones que posee el cliente.
      --solo para cuando es diario clasifica este tendra algo
      if p_tip_proceso = 'D' then
      SELECT nvl(MAX(a.cat_automatica),1)
        INTO v_cat_riesgo
        FROM ge_cla_operaciones_cla_tmp a --ge_cla_operaciones--fieldesk 14515
       WHERE a.cod_persona = p_cod_persona
         and not exists (select 1 from ba_cod_referencias where dominio = 'COD_MAD_FIDEICOMISO' and val_minimo = a.cod_modalidad);--FIELDESK-34615
      RETURN v_cat_riesgo;
      else
        SELECT nvl(MAX(a.cat_automatica), 1)
          INTO v_cat_riesgo
          FROM ge_cla_operaciones a
         WHERE a.cod_persona = p_cod_persona
         and not exists (select 1 from ba_cod_referencias where dominio = 'COD_MAD_FIDEICOMISO' and val_minimo = a.cod_modalidad);--FIELDESK-34615
        RETURN v_cat_riesgo;
      end if;
   EXCEPTION
      WHEN OTHERS THEN
         v_cat_riesgo := 1;
         RETURN v_cat_riesgo;
   END;

   FUNCTION lf_obt_cat_vta_cartera(p_cod_persona IN ge_cla_operaciones.cod_persona%TYPE)
      RETURN NUMBER AS
      v_cat_riesgo ge_cla_operaciones.cat_automatica%TYPE;
   BEGIN
      -- ya no tiene deuda en la entidad. informar la ultima antes de la venta.
      SELECT DISTINCT cat_cliente
        INTO v_cat_riesgo
        FROM pr_vta_carteras a
       WHERE a.cod_persona = p_cod_persona;
      RETURN v_cat_riesgo;

   EXCEPTION
      WHEN no_data_found THEN
         SELECT cat_riesgo
           INTO v_cat_riesgo
           FROM ge_clientes_his a
          WHERE a.cod_persona = p_cod_persona
            AND a.fecha = v_fec_ant_categoria;
         RETURN v_cat_riesgo;
      WHEN OTHERS THEN
         RETURN 1;
   END;

   FUNCTION lf_obt_rub_padre(p_cod_rubro cb_rubros.cod_rubro%TYPE) RETURN VARCHAR2 IS
      v_cod_rubro cb_rubros.cod_rubro%TYPE;
   BEGIN
      SELECT substr(cod_rub_padre, 1, 8) || '0000000'
        INTO v_cod_rubro
        FROM cb_rubros
       WHERE cod_rubro = p_cod_rubro;
      RETURN v_cod_rubro;
   EXCEPTION
      WHEN no_data_found THEN
         RETURN NULL;
      WHEN too_many_rows THEN
         RETURN NULL;
      WHEN OTHERS THEN
         RETURN NULL;
   END;

   FUNCTION lf_obt_fec_vto_cuota(p_nro_cuenta ah_cupones.nro_cuenta%TYPE) RETURN DATE IS
      v_fec_vencimiento ah_cupones.fec_vencimiento%TYPE;
   BEGIN
      SELECT MIN(fec_vencimiento)
        INTO v_fec_vencimiento
        FROM ah_cupones
       WHERE nro_cuenta = p_nro_cuenta
         AND fec_vencimiento > v_fec_fin
         AND estado <> 'P';
      RETURN v_fec_vencimiento;
   EXCEPTION
      WHEN no_data_found THEN
         RETURN NULL;
      WHEN OTHERS THEN
         RETURN NULL;
   END;

   FUNCTION lf_obt_int_cda_vencido(p_nro_cuenta ah_cupones.nro_cuenta%TYPE) RETURN NUMBER IS
      v_int_vencido ah_cupones.mto_interes%TYPE;
   BEGIN
      SELECT SUM(nvl(mto_interes, 0))
        INTO v_int_vencido
        FROM ah_cupones
       WHERE nro_cuenta = p_nro_cuenta
         AND estado = 'V';
      RETURN nvl(v_int_vencido, 0);
   EXCEPTION
      WHEN no_data_found THEN
         RETURN 0;
      WHEN OTHERS THEN
         RETURN 0;
   END;
   FUNCTION lf_obt_int_devengado(p_nro_cuenta ah_devengados.nro_cuenta%TYPE) RETURN NUMBER IS
      v_mto_dev_acumulado ah_devengados.mto_dev_acumulado%TYPE;
      v_fecha             ah_devengados.fecha%TYPE;
   BEGIN
      SELECT fecha
        INTO v_fecha
        FROM ah_devengados
       WHERE nro_cuenta = p_nro_cuenta
         AND fec_inicio = (SELECT MAX(fec_inicio)
                             FROM ah_devengados
                            WHERE nro_cuenta = p_nro_cuenta);
      SELECT SUM(nvl(mto_dev_acumulado, 0))
        INTO v_mto_dev_acumulado
        FROM ah_devengados
       WHERE nro_cuenta = p_nro_cuenta
         AND fecha = v_fecha;
      RETURN nvl(v_mto_dev_acumulado, 0);
   EXCEPTION
      WHEN no_data_found THEN
         RETURN 0;
      WHEN OTHERS THEN
         RETURN 0;
   END;
   PROCEDURE lp_crc_con_datos(rp_gcope IN sb_crc_operaciones_det%ROWTYPE) IS
      rp_slcrc       sb_log_crc%ROWTYPE;
      v_pri_vez      VARCHAR2(1);
      v_exi_vinculos VARCHAR2(1);
      v_mensaje      VARCHAR2(1000) := NULL;
   BEGIN
      -- Verifica si es la primera vez que sera informado
      BEGIN
         SELECT 'S'
           INTO v_pri_vez
           FROM sb_crc_operaciones_det
          WHERE nro_operacion = rp_gcope.nro_operacion
            AND tip_operacion = rp_gcope.tip_operacion
            AND cod_oficina = rp_gcope.cod_oficina
            AND cod_moneda = rp_gcope.cod_moneda;
      EXCEPTION
         WHEN no_data_found THEN
            v_pri_vez := 'N';
         WHEN OTHERS THEN
            v_pri_vez := 'N';
      END;
      IF v_pri_vez = 'S' THEN
         BEGIN
            -- Verifica que la operacion se encuentre en vinculos
            SELECT 'S'
              INTO v_exi_vinculos
              FROM sb_crc_vinculos_det
             WHERE nro_operacion = rp_gcope.nro_operacion
               AND tip_operacion = rp_gcope.tip_operacion
               AND cod_oficina = rp_gcope.cod_oficina
               AND cod_mon_iso = rp_gcope.cod_moneda
               AND tip_vinculo = 1;
         EXCEPTION
            WHEN no_data_found THEN
               v_mensaje := v_mensaje || ', No se encuentra registrado en el archivo de vinculos';
            WHEN too_many_rows THEN
               v_mensaje := v_mensaje || ', Varios registros en el archivo de vinculos para el tipo Deudor';
         END;
      ELSE
         IF rp_gcope.fec_pri_vencimiento < rp_gcope.fec_operacion THEN
            v_mensaje := v_mensaje || ', Fecha primer vencimiento no puede ser menor a la Fecha de Operacion';
         END IF;
         IF rp_gcope.cod_modulo = 5 AND rp_gcope.mto_lin_credito < 0 THEN
            v_mensaje := v_mensaje || ', La Linea de Credito debe ser mayor que Cero';
         END IF;
         IF rp_gcope.cta_con_cap_original IS NULL OR rp_gcope.tip_operacion IS NULL THEN
            v_mensaje := v_mensaje || ', Rubro Capital y Tipo de Operacion Nulos';
         END IF;
         IF rp_gcope.cta_con_int_original IS NULL AND rp_gcope.mto_ori_interes > 0 THEN
            v_mensaje := v_mensaje || ', Rubro Contable Interes Nulo con Saldo de Interes';
         ELSIF rp_gcope.cta_con_int_original IS NOT NULL AND rp_gcope.mto_ori_interes = 0 THEN
            v_mensaje := v_mensaje || ', Rubro Contable Interes No Nulo con Saldo de Interes Cero';
         END IF;
         IF rp_gcope.cod_rub_primario IS NULL THEN
            v_mensaje := v_mensaje || ', Codigo de Actividad Primaria Nula';
         END IF;
         IF rp_gcope.cod_rub_economico IS NULL THEN
            v_mensaje := v_mensaje || ', Codigo de Rubro economico Nulo';
         END IF;
      END IF;
      IF v_mensaje IS NOT NULL THEN
         rp_slcrc.fecha          := rp_gcope.fecha;
         rp_slcrc.nom_referencia := rp_gcope.nom_referencia;
         rp_slcrc.usu_insercion  := substr(USER, 1, 10);
         rp_slcrc.fec_insercion  := SYSDATE;
         rp_slcrc.mensaje        := 'ERROR: En la ' || rp_gcope.nom_referencia || ' nro.: ' || rp_gcope.nro_operacion ||
                                    ', Tipo Operacion: ' || rp_gcope.tip_operacion || ', Oficina: ' ||
                                    rp_gcope.cod_oficina || ', Moneda: ' || rp_gcope.cod_moneda || ' ' || v_mensaje;
         rp_slcrc.nro_registro   := rp_gcope.nro_registro;
         lp_log_crc(rp_slcrc);

      END IF;
   END;
   -- Procedimiento de generacion de Archivo de Operaciones
   PROCEDURE lp_ins_crc_operaciones(rp_gcope sb_crc_operaciones_det%ROWTYPE) IS
      v_reg_datos VARCHAR2(1); --Indica si se registran o no los datos
   BEGIN
      v_reg_datos := 'N';
      IF v_cod_entidad = 6004 THEN
         v_reg_datos := 'S';
      ELSIF rp_gcope.cod_persona NOT IN (v_cod_per_entidad, v_cod_per_bco_central) THEN
         v_reg_datos := 'S';
      ELSIF nvl(v_inc_ope_entidad, 'N') = 'S' AND rp_gcope.cod_persona = v_cod_per_entidad THEN
         v_reg_datos := 'S';
      ELSIF rp_gcope.tip_operacion = '183' /*Cheques Comprados del pais*/
       THEN
         v_reg_datos := 'S';
      END IF;
      IF v_reg_datos = 'S' THEN
         IF rp_gcope.cod_persona <> v_cod_per_bco_central THEN
            lp_crc_con_datos(rp_gcope);
            INSERT INTO sb_crc_operaciones_det
               (fecha,
                nom_referencia,
                nro_formulario,
                cod_oficina,
                tip_operacion,
                nro_operacion,
                cod_moneda,
                fec_operacion,
                fec_pri_vencimiento,
                nro_cuota,
                cta_con_cap_original,
                mto_ori_capital,
                mto_lin_credito,
                cta_con_int_original,
                mto_ori_interes,
                cod_rub_primario,
                cod_departamento,
                cod_rub_economico,
                dia_plazo,
                tas_nominal,
                nro_registro,
                cod_modulo,
                cod_persona)
            VALUES
               (rp_gcope.fecha,
                rp_gcope.nom_referencia,
                rp_gcope.nro_formulario,
                nvl(fug_obt_pardinamico('COD_OFI_NO_HAB_BCP', NULL, NULL, NULL, rp_gcope.cod_oficina),
                    rp_gcope.cod_oficina),
                rp_gcope.tip_operacion,
                rp_gcope.nro_operacion,
                rp_gcope.cod_moneda,
                rp_gcope.fec_operacion,
                rp_gcope.fec_pri_vencimiento,
                rp_gcope.nro_cuota,
                rp_gcope.cta_con_cap_original,
                nvl(pag_gen.fu_con_mon_a_moneda(decode(rp_gcope.cod_moneda, 'PYG', v_cod_mon_local, rp_gcope.cod_moneda),
                                                v_cod_mon_local,
                                                rp_gcope.mto_ori_capital,
                                                NULL,
                                                rp_gcope.fec_operacion,
                                                NULL),
                    0),
                nvl(pag_gen.fu_con_mon_a_moneda(decode(rp_gcope.cod_moneda, 'PYG', v_cod_mon_local, rp_gcope.cod_moneda),
                                                v_cod_mon_local,
                                                rp_gcope.mto_lin_credito,
                                                NULL,
                                                rp_gcope.fec_operacion,
                                                NULL),
                    0),
                rp_gcope.cta_con_int_original,
                nvl(pag_gen.fu_con_mon_a_moneda(decode(rp_gcope.cod_moneda, 'PYG', v_cod_mon_local, rp_gcope.cod_moneda),
                                                v_cod_mon_local,
                                                rp_gcope.mto_ori_interes,
                                                NULL,
                                                rp_gcope.fec_operacion,
                                                NULL),
                    0),
                rp_gcope.cod_rub_primario,
                rp_gcope.cod_departamento,
                rp_gcope.cod_rub_economico,
                rp_gcope.dia_plazo,
                rp_gcope.tas_nominal,
                rp_gcope.nro_registro,
                rp_gcope.cod_modulo,
                rp_gcope.cod_persona);
            --- Inserta Vinculos
            IF rp_gcope.tip_operacion = '183' and fug_obt_pardinamico('INF_VINCULOS_CRC', 6) = 'N' THEN
                lp_crc_gen_vinculos(rp_gcope.cod_oficina,
                                    rp_gcope.nro_operacion,
                                    rp_gcope.tip_operacion,
                                    rp_gcope.cod_modulo,
                                    rp_gcope.cta_con_cap_original,
                                    rp_gcope.cod_moneda,
                                    rp_gcope.cod_persona);
            ELSE
                lp_crc_gen_vinculos(rp_gcope.cod_oficina,
                                    rp_gcope.nro_operacion,
                                    rp_gcope.tip_operacion,
                                    rp_gcope.cod_modulo,
                                    rp_gcope.cta_con_cap_original,
                                    rp_gcope.cod_moneda);
            END IF;
         END IF;
      ELSE
         v_nro_registro := rp_gcope.nro_registro - 1;
      END IF;

   END;
       -- Procedimiento de generaci?n de Archivo de Operaciones
   PROCEDURE lp_ins_crc_ope_cta_basica(rp_gcope sb_crc_mov_cta_basica%ROWTYPE) IS
   BEGIN
      IF rp_gcope.cod_persona NOT IN (v_cod_per_bco_central)
         or (substr(rp_gcope.cta_con_cap_original,1,3)<>'250')THEN
         INSERT INTO sb_crc_mov_cta_basica
            (fecha, nom_referencia, nro_formulario, cod_oficina, tip_operacion, nro_operacion,
             cod_moneda, fec_operacion, fec_pri_vencimiento, nro_cuota, cta_con_cap_original,
             mto_ori_capital, mto_lin_credito, cta_con_int_original, mto_ori_interes, cod_rub_primario,
             cod_departamento, cod_rub_economico, dia_plazo, tas_nominal, nro_registro, cod_modulo,
             cod_persona)
         VALUES
            (rp_gcope.fecha, rp_gcope.nom_referencia, rp_gcope.nro_formulario,
             nvl(fug_obt_pardinamico('COD_OFI_NO_HAB_BCP', NULL, NULL, NULL, rp_gcope.cod_oficina),
                  rp_gcope.cod_oficina), rp_gcope.tip_operacion, rp_gcope.nro_operacion,
             rp_gcope.cod_moneda, rp_gcope.fec_operacion, rp_gcope.fec_pri_vencimiento,
             rp_gcope.nro_cuota, rp_gcope.cta_con_cap_original,
             nvl(pag_gen.fu_con_mon_a_moneda(decode(rp_gcope.cod_moneda, 'PYG',
                                                     v_cod_mon_local, rp_gcope.cod_moneda),
                                              v_cod_mon_local, rp_gcope.mto_ori_capital, NULL,
                                              rp_gcope.fec_operacion, NULL), 0),
             nvl(pag_gen.fu_con_mon_a_moneda(decode(rp_gcope.cod_moneda, 'PYG',
                                                     v_cod_mon_local, rp_gcope.cod_moneda),
                                              v_cod_mon_local, rp_gcope.mto_lin_credito, NULL,
                                              rp_gcope.fec_operacion, NULL), 0),
             rp_gcope.cta_con_int_original,
             nvl(pag_gen.fu_con_mon_a_moneda(decode(rp_gcope.cod_moneda, 'PYG',
                                                     v_cod_mon_local, rp_gcope.cod_moneda),
                                              v_cod_mon_local, rp_gcope.mto_ori_interes, NULL,
                                              rp_gcope.fec_operacion, NULL), 0),
             rp_gcope.cod_rub_primario, rp_gcope.cod_departamento, rp_gcope.cod_rub_economico,
             rp_gcope.dia_plazo, rp_gcope.tas_nominal, rp_gcope.nro_registro, rp_gcope.cod_modulo,
             rp_gcope.cod_persona);
      ELSE
         v_nro_registro := v_nro_registro - 1;
      END IF;
   END;
   -- Procedimiento de generacion de Archivo de Saldos
   PROCEDURE lp_ins_crc_saldos(rp_gcsal sb_crc_saldos_det%ROWTYPE) IS
      v_sal_int_dev_no_cobrado ge_cla_operaciones.dev_no_cobrado%type;
   BEGIN
     if rp_gcsal.nom_referencia='SALDOSV' then --Agregado porque Saldosv ya esta guaranizado --FIELDESK-34615
       v_cotizacion:= 1;
     else
      v_cotizacion := nvl(fug_obt_cotizacion(rp_gcsal.con_mon_iso, v_fec_fin), 1);
     end if;

      IF rp_gcsal.cod_modulo = 3 THEN
         v_sal_int_dev_no_cobrado := round(rp_gcsal.sal_int_dev_no_cobrado * v_cotizacion, v_redondeo);
      ELSE
         v_sal_int_dev_no_cobrado := rp_gcsal.sal_int_dev_no_cobrado;
      END IF;
      INSERT INTO sb_crc_saldos_det
         (fecha,
          nom_referencia,
          nro_formulario,
          cod_oficina,
          cod_modulo,
          cod_modalidad,
          tip_operacion,
          nro_operacion,
          fec_corte,
          fec_vto_cuota,
          fec_vto_cuo_vencida,
          dia_atraso,
          rub_con_capital,
          sal_capital,
          sal_cuo_vencida,
          nro_registro,
          con_mon_iso,
          rub_con_int_devengar,
          sal_int_devengar,
          rub_con_dev_no_cobrado,
          sal_int_dev_no_cobrado,
          rub_con_int_dev_cobrado,
          sal_int_dev_cobrado,
          rub_con_dev_suspenso,
          sal_int_suspenso,
          rub_con_contingencia,
          mto_contingencia,
          tas_efectiva,
          rub_con_prevision,
          mto_prevision,
          can_cuo_pagadas,
          cla_riesgo,
          -- NUEVOS CAMPOS:
          ind_movimiento,
          est_tarjeta,
          mto_deu_anterior,
          mto_pag_mes,
          mto_com_mes,
          mto_deu_facturar,
          mto_cargo,
          mto_lin_credito)
      VALUES
         (rp_gcsal.fecha,
          rp_gcsal.nom_referencia,
          rp_gcsal.nro_formulario,
          nvl(fug_obt_pardinamico('COD_OFI_NO_HAB_BCP', NULL, NULL, NULL, rp_gcsal.cod_oficina), rp_gcsal.cod_oficina),
          rp_gcsal.cod_modulo,
          rp_gcsal.cod_modalidad,
          rp_gcsal.tip_operacion,
          rp_gcsal.nro_operacion,
          rp_gcsal.fec_corte,
          rp_gcsal.fec_vto_cuota,
          rp_gcsal.fec_vto_cuo_vencida,
          rp_gcsal.dia_atraso,
          rp_gcsal.rub_con_capital,
          GREATEST(round(rp_gcsal.sal_capital * v_cotizacion, v_redondeo), 0),
          GREATEST(round(rp_gcsal.sal_cuo_vencida * v_cotizacion, v_redondeo), 0),
          rp_gcsal.nro_registro,
          rp_gcsal.con_mon_iso,
          rp_gcsal.rub_con_int_devengar,
          GREATEST(round(rp_gcsal.sal_int_devengar * v_cotizacion, v_redondeo), 0),
          rp_gcsal.rub_con_dev_no_cobrado,
          GREATEST(v_sal_int_dev_no_cobrado, 0),
          rp_gcsal.rub_con_int_dev_cobrado,
          GREATEST(round(rp_gcsal.sal_int_dev_cobrado * v_cotizacion, v_redondeo), 0),
          rp_gcsal.rub_con_dev_suspenso,
          GREATEST(round(rp_gcsal.sal_int_suspenso * v_cotizacion, v_redondeo), 0),
          rp_gcsal.rub_con_contingencia,
          GREATEST(rp_gcsal.mto_contingencia, 0),
          rp_gcsal.tas_efectiva,
          rp_gcsal.rub_con_prevision,
          GREATEST(rp_gcsal.mto_prevision, 0),
          rp_gcsal.can_cuo_pagadas,
          rp_gcsal.cla_riesgo,
          rp_gcsal.ind_movimiento,
          rp_gcsal.est_tarjeta,
          rp_gcsal.mto_deu_anterior,
          rp_gcsal.mto_pag_mes,
          rp_gcsal.mto_com_mes,
          rp_gcsal.mto_deu_facturar,
          rp_gcsal.mto_cargo,
          rp_gcsal.mto_lin_credito);
   END;
 FUNCTION lf_obt_sal_bloqueado(p_nro_cuenta IN cc_cta_corrientes.nro_cuenta%TYPE)
        RETURN NUMBER IS
        v_sal_bloqueado sb_crc_saldos_det.sal_capital%TYPE;
      BEGIN
        SELECT SUM(NVL(gb.monto, 0))
          INTO v_sal_bloqueado
          FROM ge_bloqueos     gb,
               ge_embargos_det ged
         WHERE gb.nro_cuenta = ged.nro_cuenta
           AND gb.nro_documento = ged.cod_embargo
           AND gb.nro_cuenta = p_nro_cuenta;
          RETURN v_sal_bloqueado;
      EXCEPTION
        WHEN no_data_found THEN
          RETURN 0;
        WHEN OTHERS THEN
          RETURN 0;
      END;

   -- Procedimiento de generacion de Archivo de Saldos
   PROCEDURE lp_ins_crc_clasificaciones(rp_sccla sb_crc_clasificaciones_det%ROWTYPE) IS
   BEGIN
      INSERT INTO sb_crc_clasificaciones_det
         (fecha,
          nom_referencia,
          nro_formulario,
          nro_registro,
          tip_documento,
          nro_documento,
          fec_nacimiento,
          nombres,
          apellidos,
          cat_riesgo,
          cat_subjetiva,
          cat_rie_fideicomiso,
          por_prevision,
          mto_rie_contingente,
          mto_riesgo,
          sal_cap_vencido,
          sal_int_vencido,
          tot_garantia,
          tot_cap_pri_prevision,
          tot_cap_seg_prevision,
          tot_int_pri_prevision,
          tot_int_seg_prevision,
          tot_tc,
          tot_dc,
          tot_tr,
          tot_dr,
          tot_er,
          tot_sr,
          cod_persona,
          mto_vta_cartera,
          mto_deu_incobrable
          )
      VALUES
         (rp_sccla.fecha,
          rp_sccla.nom_referencia,
          rp_sccla.nro_formulario,
          rp_sccla.nro_registro,
          rp_sccla.tip_documento,
          rp_sccla.nro_documento,
          rp_sccla.fec_nacimiento,
          rp_sccla.nombres,
          rp_sccla.apellidos,
          rp_sccla.cat_riesgo,
          rp_sccla.cat_subjetiva,
          rp_sccla.cat_rie_fideicomiso,
          rp_sccla.por_prevision,
          rp_sccla.mto_rie_contingente,
          rp_sccla.mto_riesgo,
          rp_sccla.sal_cap_vencido,
          rp_sccla.sal_int_vencido,
          rp_sccla.tot_garantia,
          rp_sccla.tot_cap_pri_prevision,
          rp_sccla.tot_cap_seg_prevision,
          rp_sccla.tot_int_pri_prevision,
          rp_sccla.tot_int_seg_prevision,
          rp_sccla.tot_tc,
          rp_sccla.tot_dc,
          rp_sccla.tot_tr,
          rp_sccla.tot_dr,
          rp_sccla.tot_er,
          rp_sccla.tot_sr,
          rp_sccla.cod_persona,
          rp_sccla.mto_vta_cartera,
          rp_sccla.mto_deu_incobrable);
   END;
   PROCEDURE pr_crc_gen_vta_cartera(p_periodo in varchar2) IS

      CURSOR c_saldos IS
         SELECT sc.fecha, sc.cod_modulo, g.cod_modalidad, sc.cod_oficina, sc.nro_operacion, sc.tip_operacion,
                sc.cod_moneda, sc.fec_pri_vencimiento, g.cat_cliente, g.dia_atraso, g.mto_capital,
                g.sal_capital, g.dev_no_cobrado, sc.cta_con_cap_original, g.nro_cuenta
           FROM sb_crc_operaciones_det sc, pr_vta_carteras g
          WHERE pae_uti.fu_obt_valor(sc.nro_operacion, 1) = g.nro_cuenta
            AND nvl(g.ope_recaptada, 'N') = 'N'
            AND (v_fec_fin - g.fec_ope_ente) <= v_crc_can_dia_incobrable
            AND p_periodo = 'M';

      rp_gcsal              sb_crc_saldos_det%ROWTYPE;
      v_rub_contable        cb_rubros.cod_rubro%TYPE;
      v_dev_no_cobrado      ge_cla_operaciones.dev_no_cobrado%TYPE;
      v_tot_prevision       ge_cla_operaciones.tot_prevision%TYPE;
      v_tot_deu_contingente ge_cla_operaciones.tot_deu_contingente%TYPE;
      v_tot_gar_computables ge_cla_operaciones.tot_gar_computables%TYPE;
      v_cat_automatica      ge_cla_operaciones.cat_automatica%TYPE;
      v_cat_riesgo          ge_cla_operaciones.cat_automatica%TYPE;
      v_cod_tra_vta_cartera ge_transacciones.cod_transaccion%TYPE;
   BEGIN
      rp_gcsal.nom_referencia := 'SALDOS';
      rp_gcsal.nro_formulario := '003';
      FOR i IN c_saldos LOOP
        v_rub_contable := null;

         DELETE sb_crc_saldos_det
          WHERE fecha = v_fec_fin
            and nro_operacion = i.nro_operacion;

         lp_obt_dat_cla_operaciones(i.nro_cuenta,
                                    v_dev_no_cobrado,
                                    v_tot_prevision,
                                    v_tot_deu_contingente,
                                    v_tot_gar_computables,
                                    v_cat_automatica);
         v_cat_riesgo := fue_obt_des_refcodes('CAT_RIE_BCP', replace(v_cat_automatica, ',', '.'));
         IF upper(v_cat_riesgo) like upper('%Referencia%Sistema%') THEN
            v_cat_riesgo := fue_obt_des_refcodes('CAT_RIE_BCP', replace(v_cat_automatica, '.', ','));
         END IF;
         rp_gcsal.cla_riesgo := 6;
         v_cod_tra_vta_cartera := fug_obt_pardinamico('SIB_COD_TRA_VTA_CARTERA', i.cod_modulo, i.cod_modalidad);

         if v_cod_tra_vta_cartera is null then
            raise_application_error(-20000, 'Error al obtener parametro COD_TRA_VTA_CARTERA');
         end if;
         IF v_rub_contable IS NULL THEN
            v_rub_contable := fu_obt_cod_rubro(i.nro_cuenta,null,null, v_cod_tra_vta_cartera, null,null,null,null,null, 'D',null,null,null,null,null,null,null);

         END IF;
         if v_rub_contable is null then
            v_rub_contable := i.cta_con_cap_original;
         end if;

         rp_gcsal.fecha                   := v_fec_fin;
         rp_gcsal.cod_modulo              := i.cod_modulo;
         rp_gcsal.cod_oficina             := i.cod_oficina;
         rp_gcsal.con_mon_iso             := i.cod_moneda;
         rp_gcsal.tas_efectiva            := 0;
         rp_gcsal.sal_capital             := nvl(i.sal_capital, 0) + nvl(i.dev_no_cobrado, 0);
         rp_gcsal.cod_modalidad           := i.cod_modalidad;
         rp_gcsal.tip_operacion           := i.tip_operacion;
         rp_gcsal.nro_operacion           := i.nro_operacion;
         rp_gcsal.fec_corte               := v_fec_fin;
         rp_gcsal.fec_vto_cuota           := NULL;
         rp_gcsal.fec_vto_cuo_vencida     := NULL;
         rp_gcsal.dia_atraso              := i.dia_atraso;
         rp_gcsal.sal_cuo_vencida         := nvl(i.sal_capital, 0) + nvl(i.dev_no_cobrado, 0);
         rp_gcsal.rub_con_int_devengar    := NULL;
         rp_gcsal.sal_int_devengar        := 0;
         rp_gcsal.rub_con_dev_no_cobrado  := NULL;
         rp_gcsal.sal_int_dev_no_cobrado  := 0;
         rp_gcsal.rub_con_int_dev_cobrado := NULL;
         rp_gcsal.rub_con_dev_suspenso    := NULL;
         rp_gcsal.sal_int_suspenso        := 0;
         rp_gcsal.sal_int_dev_cobrado     := 0;
         rp_gcsal.mto_prevision           := 0;
         rp_gcsal.rub_con_prevision       := NULL;
         rp_gcsal.rub_con_contingencia    := NULL;
         rp_gcsal.mto_contingencia        := 0;
         rp_gcsal.can_cuo_pagadas         := 0;
         rp_gcsal.rub_con_capital         := v_rub_contable;

         IF rp_gcsal.sal_capital is not null and rp_gcsal.cod_modalidad is not null then
            v_nro_registro        := v_nro_registro + 1;
            rp_gcsal.nro_registro := v_nro_registro;
            lp_ins_crc_saldos(rp_gcsal);
         END IF;
      END LOOP;
   END;

procedure pr_crc_vta_cartera(p_periodo in varchar2 default 'M') is --FIELDESK-34615
     v_fec_fin  ge_calendarios.fec_actual%type ;
      cursor c_saldos is

            select g.fec_ope_ente fecha,
                     decode(g.cod_modulo,6,6,g.cod_modulo) cod_modulo,
                    g.cod_modalidad,
                    g.cod_oficina,
                    g.nro_cuenta_bt nro_operacion,
                    g.tip_operacion,
                    decode(g.cod_moneda,'GS','PYG','USD','USD') cod_moneda,
                    g.fec_vencimiento fec_pri_vencimiento,
                    g.cat_cliente,
                    g.dia_atraso,
                    g.mto_capital,
                    g.sal_capital,
                    g.dev_no_cobrado,
                    decode (g.cod_moneda,'GS', '510406970400099','USD','510406970400001') cta_con_cap_original,
                    g.nro_cuenta
               from  sb_crc_vta_carteras g
              where  nvl(g.ope_recaptada, 'N') = 'N'
                 and p_periodo = 'M'
                 and nvl(g.estado_vta_cartera,'N')='C';

      rp_gcsal              sb_crc_saldos_det%rowtype;
      v_rub_contable        cb_rubros.cod_rubro%type;
      v_dev_no_cobrado      ge_cla_operaciones.dev_no_cobrado%type;
      v_tot_prevision       ge_cla_operaciones.tot_prevision%type;
      v_tot_deu_contingente ge_cla_operaciones.tot_deu_contingente%type;
      v_tot_gar_computables ge_cla_operaciones.tot_gar_computables%type;
      v_cat_automatica      ge_cla_operaciones.cat_automatica%type;
      v_cat_riesgo          ge_cla_operaciones.cat_automatica%type;
      v_cod_tra_vta_cartera ge_transacciones.cod_transaccion%type;
      v_nro_registro number(18):=0;


   begin
      pag_cal.pr_obt_dat_calendar(1);
      v_fec_fin := pag_cal.g_ult_dia_mes;
      rp_gcsal.nom_referencia := 'SALDOSV';
      rp_gcsal.nro_formulario := '003';

      delete sb_crc_saldos_det
      where fecha = v_fec_fin
      and nom_referencia='SALDOSV';
      commit;

     select NVL(max(nro_registro), 0)
     into v_nro_registro
     from sb_Crc_saldos_det
     where  nom_referencia='SALDOS'
     and fecha = v_fec_fin;

      for i in c_saldos loop
        v_rub_contable := null;


          lp_obt_dat_cla_operaciones(i.nro_cuenta,
                                    v_dev_no_cobrado,
                                    v_tot_prevision,
                                    v_tot_deu_contingente,
                                    v_tot_gar_computables,
                                    v_cat_automatica);
        /* v_cat_riesgo := fue_obt_des_refcodes('CAT_RIE_BCP', replace(v_cat_automatica, ',', '.'));
         if upper(v_cat_riesgo) like upper('%Referencia%Sistema%') then
            v_cat_riesgo := fue_obt_des_refcodes('CAT_RIE_BCP', replace(v_cat_automatica, '.', ','));
         end if;*/
         rp_gcsal.cla_riesgo:= i.cat_cliente;
         v_rub_contable := i.cta_con_cap_original;

         rp_gcsal.fecha                   := v_fec_fin;
         rp_gcsal.cod_modulo              := i.cod_modulo;
         rp_gcsal.cod_oficina             := i.cod_oficina;
         rp_gcsal.con_mon_iso             := i.cod_moneda;
         rp_gcsal.tas_efectiva            := 0;
         rp_gcsal.sal_capital             := nvl(i.sal_capital, 0);
         rp_gcsal.cod_modalidad           := i.cod_modalidad;
         rp_gcsal.tip_operacion           := i.tip_operacion;
         rp_gcsal.nro_operacion           := i.nro_operacion;
         rp_gcsal.fec_corte               := v_fec_fin;
         rp_gcsal.fec_vto_cuota           := last_day(add_months(v_fec_fin,1));
         rp_gcsal.fec_vto_cuo_vencida     := null;
         rp_gcsal.dia_atraso              := nvl(i.dia_atraso,0);
         rp_gcsal.sal_cuo_vencida         := 0;
         rp_gcsal.rub_con_int_devengar    := null;
         rp_gcsal.sal_int_devengar        := 0;
         rp_gcsal.rub_con_dev_no_cobrado  := null;
         rp_gcsal.sal_int_dev_no_cobrado  := 0;
         rp_gcsal.rub_con_int_dev_cobrado := null;
         rp_gcsal.rub_con_dev_suspenso    := null;
         rp_gcsal.sal_int_suspenso        := 0;
         rp_gcsal.sal_int_dev_cobrado     := 0;
         rp_gcsal.mto_prevision           := 0;
         rp_gcsal.rub_con_prevision       := null;
         rp_gcsal.rub_con_contingencia    := null;
         rp_gcsal.mto_contingencia        := 0;
         rp_gcsal.can_cuo_pagadas         := 0;
         rp_gcsal.rub_con_capital         := v_rub_contable;

         if rp_gcsal.sal_capital is not null  then
            IF i.tip_operacion = '205' THEN
               rp_gcsal.ind_movimiento   := 'N';
               rp_gcsal.est_tarjeta      := 2;
               rp_gcsal.mto_deu_anterior := 0;
               rp_gcsal.mto_pag_mes      := 0;
               rp_gcsal.mto_com_mes      := 0;
               rp_gcsal.mto_deu_facturar := 0;
               rp_gcsal.mto_cargo        := 0;
               rp_gcsal.mto_lin_credito  := 0;
            ELSE
               rp_gcsal.ind_movimiento   := NULL;
               rp_gcsal.est_tarjeta      := NULL;
               rp_gcsal.mto_deu_anterior := NULL;
               rp_gcsal.mto_pag_mes      := NULL;
               rp_gcsal.mto_com_mes      := NULL;
               rp_gcsal.mto_deu_facturar := NULL;
               rp_gcsal.mto_cargo        := NULL;
               rp_gcsal.mto_lin_credito  := NULL;
            END IF;
            v_nro_registro        := v_nro_registro + 1;
            rp_gcsal.nro_registro := v_nro_registro;
            lp_ins_crc_saldos(rp_gcsal);
         end if;
      end loop;
   end;

   -- Procedimientos que contiene los datos exigidos para el modulo de Prestamos
   PROCEDURE pr_crc_gen_saldos IS
      CURSOR c_saldos(v_periodo IN VARCHAR2, v_mod_procesar in NUMBER) IS
      select det.* from (
            SELECT sc.fecha,
                sc.cod_modulo,
                sc.cod_oficina,
               CASE
                  WHEN ge.cod_modalidad = 34 THEN sc.nro_operacion
                  ELSE pas_cri.fu_obt_operacion(sc.nro_operacion, 1)
               END nro_operacion,
                pas_cri.fu_obt_operacion(sc.nro_operacion, 2) sub_tip_ope,
                pas_cri.fu_obt_operacion(sc.nro_operacion, 3) nro_cuo_descuento,
                sc.nro_operacion nro_ope_original,
                sc.tip_operacion,
                sc.cod_moneda,
                sc.cta_con_cap_original,
                sc.fec_pri_vencimiento,
                'A' tip_renovacion,
                p.cod_persona,
                ge.cod_modalidad,
                ge.nro_cuenta,
                sc.fec_operacion
           FROM sb_crc_operaciones_det sc, ge_cuentas ge,ba_cod_referencias b, ba_personas p, ge_cta_clientes g,ge_est_cuentas gt
          WHERE (pae_uti.fu_obt_valor(sc.nro_operacion,1) = ge.nro_cuenta OR
                 (ge.cod_modalidad = 34 AND (sc.nro_operacion, ge.nro_cuenta) IN
                     (SELECT x.cod_isin, x.nro_cuenta
                        FROM (SELECT h.cod_isin, h.nro_cuenta,
                                     ROW_NUMBER() OVER (PARTITION BY h.cod_isin
                                                        ORDER BY CASE WHEN h.estado IN ('A', 'X') THEN 1 ELSE 0 END,
                                                                 h.fec_apertura DESC, h.nro_cuenta DESC) rn
                                FROM ah_cta_certificados h
                               WHERE h.cod_modalidad = 34
                                 AND h.cod_isin IS NOT NULL) x
                       WHERE x.rn = 1)))
          AND ge.cod_modulo = gt.cod_modulo
          AND ge.cod_modalidad = gt.cod_modalidad
          AND ge.estado = gt.estado
          AND gt.activo = 'S'
          and b.dominio = 'SIB_RUC_CLI_CRC_SALDOS'
          AND p.nro_documento = b.val_minimo
          and ge.nro_cuenta = g.nro_cuenta
          AND to_number(g.cod_persona) = p.cod_persona
          AND sc.COD_MODULO = v_mod_procesar
          AND g.relacion = 'P'
          -- AND IT.pas_cri.fu_ruc_sal_diario(ge.nro_cuenta) = 'S'
            AND v_periodo = 'D'
             UNION ALL
            /*SELECT sc.fecha,
                sc.cod_modulo,
                sc.cod_oficina,
                IT.pas_cri.fu_obt_operacion(sc.nro_operacion, 1) nro_operacion,
                IT.pas_cri.fu_obt_operacion(sc.nro_operacion, 2) sub_tip_ope,
                IT.pas_cri.fu_obt_operacion(sc.nro_operacion, 3) nro_cuo_descuento,
                sc.nro_operacion nro_ope_original,
                sc.tip_operacion,
                sc.cod_moneda,
                sc.cta_con_cap_original,
                sc.fec_pri_vencimiento,
                'A' tip_renovacion,
                sc.cod_persona,
                ge.cod_modalidad,
                ge.nro_cuenta,
                sc.fec_operacion
           FROM sb_crc_operaciones_det sc, ge_cuentas ge,ge_che_custodias v, pr_rel_chq_lib rel,ge_est_cuentas g
          WHERE pae_uti.fu_obt_valor(sc.nro_operacion,1) = ge.nro_cuenta
          AND ge.cod_modulo = g.cod_modulo
          AND ge.cod_modalidad = g.cod_modalidad
          AND ge.estado = g.estado
          AND g.activo = 'S'
          and v.nro_referencia = ge.nro_cuenta
          AND rel.nro_cheque = v.nro_cheque
          AND rel.cod_banco = v.cod_banco
          AND rel.cta_libradora = v.cta_libradora
          AND EXISTS (SELECT 1
                  FROM pr_chq_libradores lib, ba_cod_referencias q
                 WHERE lib.nro_documento = q.val_minimo
                   and q.dominio = 'SIB_RUC_CLI_CRC_SALDOS'
                   and lib.nro_documento = rel.nro_documento)
           AND v_periodo = 'D'
           AND sc.COD_MODULO = v_mod_procesar
          UNION ALL*/
         SELECT  sc.fecha,
                nvl(sc.cod_modulo,ge.cod_modulo)cod_modulo,
                sc.cod_oficina,
                CASE
                   WHEN ge.cod_modalidad = 34 THEN sc.nro_operacion
                   ELSE pas_cri.fu_obt_operacion(sc.nro_operacion, 1)
                END nro_operacion,
                pas_cri.fu_obt_operacion(sc.nro_operacion, 2) sub_tip_ope,
                pas_cri.fu_obt_operacion(sc.nro_operacion, 3) nro_cuo_descuento,
                sc.nro_operacion nro_ope_original,
                sc.tip_operacion,
                sc.cod_moneda,
                sc.cta_con_cap_original,
                sc.fec_pri_vencimiento,
                'A' tip_renovacion,
                cod_persona,
                NVL(ge.cod_modalidad, 7),
                CASE
                   WHEN ge.cod_modalidad = 34 THEN ge.nro_cuenta
                   ELSE fus_obt_cta_renovada(sc.nro_operacion, sc.cod_modulo)
                END nro_cuenta,
                sc.fec_operacion
           FROM sb_crc_operaciones_det sc
                LEFT JOIN (SELECT x.cod_isin, x.nro_cuenta
                             FROM (SELECT h.cod_isin, h.nro_cuenta,
                                          ROW_NUMBER() OVER (PARTITION BY h.cod_isin
                                                             ORDER BY CASE WHEN h.estado IN ('A', 'X') THEN 1 ELSE 0 END,
                                                                      h.fec_apertura DESC, h.nro_cuenta DESC) rn
                                     FROM ah_cta_certificados h
                                    WHERE h.cod_modalidad = 34
                                      AND h.cod_isin IS NOT NULL) x
                            WHERE x.rn = 1) hc ON hc.cod_isin = sc.nro_operacion
                LEFT JOIN ge_cuentas ge ON ge.nro_cuenta = NVL(hc.nro_cuenta, pas_cri.fu_obt_operacion(sc.nro_operacion, 1))
          WHERE 1 = 1
           -- AND ge.cod_modulo = g.cod_modulo
           -- AND ge.cod_modalidad = g.cod_modalidad
          --  AND ge.estado = g.estado
          --  AND g.activo = 'S'
            and not exists (select 1
                   from ba_cod_referencias
                  where dominio = 'COD_MAD_FIDEICOMISO'
                    and val_minimo = ge.cod_modalidad)
            AND NOT EXISTS (SELECT 1
                   FROM pr_vta_carteras c
                  WHERE c.nro_cuenta = ge.nro_cuenta
                    and c.ope_recaptada = 'N')
            AND v_periodo = 'M'
            AND sc.COD_MODULO = v_mod_procesar
         UNION ALL
         SELECT p.fec_inicio,
                p.cod_modulo,
                p.cod_oficina,
                it.pas_cri.fu_obt_operacion(p.nro_cuenta, 1) nro_operacion,
                it.pas_cri.fu_obt_operacion(p.nro_cuenta, 2) sub_tip_ope,
                it.pas_cri.fu_obt_operacion(p.nro_cuenta, 3) nro_cuo_descuento,
                p.nro_cuenta nro_ope_original,
                NULL,
                it.pas_cri.fu_obt_mon_iso(p.cod_moneda),
                CASE
                  WHEN p.cod_modalidad IN (628/*, 629*/) THEN
                   pab_asi.fu_obt_rub_contable(p.nro_cuenta, 'F')
                  ELSE
                   pab_asi.fu_obt_rub_contable(p.nro_cuenta, 'C')
                END,
                NULL,
                p.tip_renovacion,
                b.cod_persona,
                p.cod_modalidad,
                b.nro_cuenta,
                null
           FROM pr_cta_prestamos p, ge_est_cuentas g, ge_cta_clientes b
          WHERE p.nro_cuenta = b.nro_cuenta
            AND b.relacion = 'P'
            AND p.cod_modulo = g.cod_modulo
            AND p.cod_modalidad = g.cod_modalidad
            AND p.estado = g.estado
            AND g.activo = 'S'
            AND v_cod_entidad = 6004
            AND p.tip_renovacion = 'N'
            AND p.estado <> 'N'
            AND NOT EXISTS (SELECT 1
                   FROM sb_crc_operaciones_det c
                  WHERE c.nro_operacion = p.nro_cuenta)
            AND it.pas_cri.fu_pue_env_bcp(substr((CASE
                                        WHEN p.cod_modalidad IN (628/*, 629*/) THEN
                                         pab_asi.fu_obt_rub_contable(p.nro_cuenta, 'F')
                                        ELSE
                                         pab_asi.fu_obt_rub_contable(p.nro_cuenta, 'C')
                                      END),
                                      6,
                                      3)) = 'S'
           AND p.COD_MODULO = v_mod_procesar
                                       ) det
           where not exists (select 1 from it.sb_crc_ope_det_proc proc
                               where proc.NRO_OPERACION   = det.nro_ope_original
                                AND proc.TIP_OPERACION  = det.TIP_OPERACION
                                AND proc.CON_MON_ISO = det.cod_moneda
                                AND proc.COD_OFICINA = det.COD_OFICINA)
                    ;

      rp_gcsal                 sb_crc_saldos_det%ROWTYPE;
      rp_slcrc                 sb_log_crc%ROWTYPE;
      v_est_batch              pr_cta_prestamos.est_batch%TYPE;
      v_estado                 pr_cta_prestamos.estado%TYPE;
      v_tip_cierre             ta_cta_tarjetas.tip_cierre%TYPE;
      v_tas_efectiva           ta_cta_tarjetas.tas_efectiva%TYPE;
      v_est_tarjeta            ta_cta_tarjetas.estado%TYPE;
      v_fec_apertura           ta_cta_tarjetas.fec_apertura%TYPE;
      v_dev_no_cobrado         ge_cla_operaciones.dev_no_cobrado%TYPE;
      v_tot_prevision          ge_cla_operaciones.tot_prevision%TYPE;
      v_nro_cuenta             sb_crc_operaciones_det.nro_operacion%TYPE;
      v_nro_cuota              pr_cuotas.nro_cuota%TYPE;
      v_nro_cheque             ge_che_custodias.cta_libradora%TYPE;
      v_can_cuo_vencidas       pr_cta_prestamos.can_cuotas%type;
      v_can_cuo_rrr            pr_cta_prestamos.can_cuotas%type;
      v_sal_cuo_vencida        pr_cuotas.mto_capital%type;
      v_tot_deu_contingente    ge_cla_operaciones.tot_deu_contingente%TYPE;
      v_tot_gar_computables    ge_cla_operaciones.tot_gar_computables%TYPE;
      v_cat_automatica         ge_cla_operaciones.cat_automatica%TYPE;
      v_fec_vencimiento        sb_crc_saldos_det.fec_vto_cuota%TYPE;
      v_tip_operacion          pr_cta_prestamos.tipo%TYPE;
      v_cat_riesgo             ba_cod_referencias.significado%TYPE;
      v_nro_cta_anterior       pr_cta_prestamos.nro_cuenta%TYPE;
      v_can_cuotas             pr_cta_prestamos.can_cuotas%TYPE;
      v_nro_cta_renovada       pr_cta_prestamos.nro_cta_renovada%TYPE;
      v_dia_atraso             pr_cta_prestamos.dia_atraso%type;
      v_tip_renovacion         pr_cta_prestamos.tip_renovacion%TYPE;
      v_fec_ult_capitalizacion ah_cta_vistas.fec_ult_capitalizacion%TYPE;
      v_cod_moneda             ba_monedas.cod_moneda%TYPE;
      v_int_cda_vencido        ah_cupones.mto_interes%TYPE;
      v_sal_int_dev_cobrado    ah_devengados.mto_dev_acumulado%TYPE;
      v_fec_tas_ape            sb_crc_operaciones_det.fecha%TYPE;
      v_cod_rubro              cb_rubros.cod_rubro%TYPE;
      v_cod_persona            ba_personas.cod_persona%TYPE;
      v_nro_cuo_vigente        pr_cuotas.nro_cuota%TYPE;
      v_sal_cuo_vigente        pr_cuotas.sal_capital%TYPE;
      v_sal_capital            pr_cuotas.sal_capital%TYPE;
      v_sal_bloqueado          sb_crc_saldos_det.sal_capital%TYPE;
      -- Variables utilizadas en el proceso de operaciones vencidas.
      v_error           NUMBER;
      v_cobrado         NUMBER(18, 2);
      v_tot_mora        NUMBER(18, 2);
      v_tot_punitorio   NUMBER(18, 2);
      v_tot_impuesto    NUMBER(18, 2);
      v_tot_cargo       NUMBER(18, 2);
      v_tot_car_iva     NUMBER(18, 2);
      v_dia_mora        NUMBER(18, 2);
      v_men_ope_vencida VARCHAR2(10000) := NULL;
      v_periodo         VARCHAR2(1);
      v_cod_tra_padre   ge_transacciones.cod_transaccion%TYPE;
      v_tip_movimiento  ge_tip_asientos.tip_movimiento%TYPE;
      v_cod_transaccion ge_transacciones.cod_transaccion%TYPE;
      ---
      v_nro_ope_vencida        ta_tarjetas.nro_tarjeta%type;
      v_nro_ope_ori_vencida    ge_cuentas.nro_cuenta%type;
      v_tip_ope_vencida        sb_crc_operaciones_det.tip_operacion%type;
      v_cod_ofi_vencida        sb_crc_operaciones_det.cod_oficina%type;
      v_cod_modulo             ge_cla_operaciones.cod_modulo%type;
      v_cod_modalidad          ge_cla_operaciones.cod_modalidad%type;
      rp_gcsal_blo_batch    cc_cta_corrientes.sal_blo_batch%TYPE;
      rp_gcsal_tot_batch    cc_cta_corrientes.sal_tot_batch%TYPE;
      rp_gcsal_ret_batch    cc_cta_corrientes.sal_ret_batch%TYPE;
      v_cod_sec_contable    ge_clientes.cod_sec_contable%TYPE;
      v_cod_tip_deudor      ge_clientes.cod_tip_deudor%TYPE;
      v_tip_ope_cta_cte     varchar2(1);
      v_mto_pignorado       ge_bloqueos.monto%TYPE;
      v_rub_con_pignorado   sb_crc_saldos_det.rub_con_capital%TYPE;
      v_sit_deuda           cc_sobregiros_res.sit_deuda%TYPE;
      v_sit_deu_prevision   cc_sobregiros_res.sit_deuda%TYPE;
      v_residente           ge_clientes.residente%TYPE;
      v_mto_lin_sobregiro   NUMBER(22,2);
      v_sob_sin_acuerdo     NUMBER(22,2);
      v_sob_con_acuerdo     NUMBER(22,2);
      v_pre_sin_acuerdo     NUMBER(22,2);
      v_pre_con_acuerdo     NUMBER(22,2);
      v_tip_ope_pignorado   varchar2(1);
      v_cod_sit_contable    md_cta_documentos.cod_sit_contable%TYPE;
      v_saldo_cci           cx_cta_importaciones.saldo%TYPE;
      v_mto_prepago         cx_cta_importaciones.mto_prepago%TYPE;
      v_rub_capital         sb_crc_saldos_det.rub_con_capital%TYPE;
      v_mto_utilizado       cx_embarques.mto_utilizado%TYPE;
      v_sal_utilizado       cx_embarques.saldo%TYPE;
      v_monto_cci           cx_cta_importaciones.monto%TYPE;
      v_cod_ofi_procesada   sb_crc_operaciones_det.cod_oficina%type;
      v_tip_ope_procesada   sb_crc_operaciones_det.tip_operacion%type;
      v_nro_ope_procesada   sb_crc_operaciones_det.nro_operacion%type;
      v_con_mon_iso         sb_crc_operaciones_det.cod_moneda%type;
      v_fec_ult_operacion   ta_cta_tarjetas.fec_ult_operacion%TYPE;
      v_fec_ult_movimiento  ah_cta_vistas.fec_ult_movimiento%TYPE;
      v_tiene_extracto      NUMBER;
      v_en_vta_cartera      NUMBER;
      v_can_reproceso       NUMBER:=0;
      i c_saldos%rowtype;
      v_exi_ope_ccc_sobregiro        number:=0;
      v_tip_op_cta_corriente         varchar2(50):= fug_obt_pardinamico('TIP_OPE_CTA_CORRIENTES');
      v_tip_op_sob_gir_cta_corriente varchar2(50):= fug_obt_pardinamico('TIP_OPE_SOB_GIR_CTA_CORRIENTES');
      V_TI_OPE_ACTIVO varchar2(3);
      V_TI_OPE_PASIVO varchar2(3);
      v_pos_cad_cta_corriente        number(2) :=0;
      v_pos_cad_cta_cte_sobregiro    number(2) :=0;
      ---

      PROCEDURE lp_crc_gen_dat_saldos(p_tip_periodo IN VARCHAR2 DEFAULT 'M') IS
      BEGIN
         pag_cal.pr_obt_dat_calendar(1);
         v_fec_actual  := pag_cal.fu_obt_fec_actual(1);
         v_fec_inicio  := pag_cal.fu_obt_fec_actual(1);
         v_fec_fin     := pag_cal.fu_obt_fec_actual(1);
         v_fec_tas_ape := pag_cal.G_ULT_DIA_MES_HABIL;
         v_fec_proxima := last_day(v_fec_actual);

         IF p_tip_periodo = 'Q' THEN
            IF to_number(to_char(v_fec_actual, 'DD')) > 15 THEN
               -- Si la fecha de proceso es mayor a 15 tomar la primera quincena para procesar del 1 al 15
               v_fec_inicio := to_date('01' || to_char(v_fec_actual, 'mmyyyy'), 'ddmmyyyy');
               v_fec_fin    := to_date('15' || to_char(v_fec_actual, 'mmyyyy'), 'ddmmyyyy');
            ELSE
               -- Si la fecha de proceso es menor a 15 tomar la segunda quincena para procesar del 16
               -- al ultimo dia del mes anterior a la fecha de proceso.
               v_fec_inicio := to_date('16' || to_char(add_months(v_fec_actual, -1), 'mmyyyy'), 'ddmmyyyy');
               v_fec_fin    := last_day(v_fec_inicio);
            END IF;
         ELSIF p_tip_periodo = 'D' THEN
            v_fec_inicio := pag_cal.fu_obt_fec_actual(1);
            v_fec_fin    := pag_cal.fu_obt_fec_actual(1);
         ELSIF p_tip_periodo = 'M' THEN
            v_fec_inicio := pag_cal.g_pri_dia_mes;
            v_fec_fin    := pag_cal.g_ult_dia_mes;
         END IF;

         if p_tip_periodo = 'M' THEN  --> SOLO EN EL MENSUAL EVALUAR LIBERAR O NO LA TMP DE PROCESO. POR AHORA QUEDA PENDIENTE LOGICA DE REPROCESO
             select count(1) into v_can_reproceso from it.sb_crc_ope_det_proc;
         ELSE
             v_can_reproceso:=0;
         END IF;


        if v_can_reproceso = 0 then
            DELETE /*+ ENABLE_PARALLEL_DML PARALLEL(8) */ sb_crc_saldos_det
            WHERE fecha BETWEEN v_fec_fin AND v_fec_fin
            AND nom_referencia = 'SALDOS';

            DELETE /*+ PARALLEL(8) */ sb_log_crc
            WHERE nom_referencia = 'SALDOS'
            AND fecha = v_fec_fin;

            DELETE /*+ PARALLEL(8) */ it.sb_crc_ope_det_proc;

            v_nro_registro := 0;
         else
            select max(nro_registro) into v_nro_registro from  sb_crc_saldos_det
            WHERE fecha BETWEEN v_fec_fin AND v_fec_fin
            AND nom_referencia = 'SALDOS';
         end if;

         DELETE sb_crc_saldos
         WHERE fec_periodo BETWEEN v_fec_fin AND v_fec_fin;
         COMMIT;

      END;
      --- Obtiene los datos correspondientes a las fechas de las operaciones de Descuentos de Cheques y Documentos
      --- Ya que debe obtener cada dato por nro. de cheques
      -- Obtiene datos correspondientes a los saldos
      PROCEDURE lp_obt_dat_cta_cheque(p_fec_proceso         IN sb_crc_operaciones_det.fecha%TYPE,
                                      p_nro_operacion       IN sb_crc_operaciones_det.nro_operacion%TYPE,
                                      p_nro_cuota           IN ge_che_custodias.nro_cheque%TYPE,
                                      p_nro_cheque          IN ge_che_custodias.cta_libradora%TYPE,
                                      p_fec_vto_cuota       OUT pr_cuotas.fec_vencimiento%TYPE,
                                      p_fec_pri_cuo_vencida OUT pr_cuotas.fec_vencimiento%TYPE,
                                      p_mto_cuo_vencida     OUT pr_cuotas.mto_capital%TYPE,
                                      p_can_cuo_vencida     OUT pr_cta_prestamos.can_cuotas%type

                                      ) IS
         -- Obtiene la fecha de vencimiento de la siguiente cuota
         FUNCTION lf_obt_fec_vto_cheque(p_fec_proceso   IN sb_crc_operaciones_det.fecha%TYPE,
                                        p_nro_operacion IN sb_crc_operaciones_det.nro_operacion%TYPE,
                                        p_nro_cuota     IN pr_cuotas.nro_cuota%TYPE,
                                        p_nro_cheque    IN ge_che_custodias.cta_libradora%TYPE) RETURN DATE IS
            v_fec_vencimiento DATE;
         BEGIN
            SELECT MIN(fec_vencimiento)
              INTO v_fec_vencimiento
              FROM pr_cuotas
             WHERE estado <> 'N'
               AND nro_cuenta =  p_nro_operacion
             ORDER BY fec_vencimiento ASC;
            RETURN v_fec_vencimiento;
         EXCEPTION
            WHEN OTHERS THEN
               RETURN NULL;
         END;
         -- Obtiene la fecha de vencimiento de la primera cuota impaga
         FUNCTION lf_obt_fec_pri_cuo_che_ven(p_fec_proceso   IN sb_crc_operaciones_det.fecha%TYPE,
                                             p_nro_operacion IN sb_crc_operaciones_det.nro_operacion%TYPE,
                                             p_nro_cuota     IN pr_cuotas.nro_cuota%TYPE,
                                             p_nro_cheque    IN ge_che_custodias.cta_libradora%TYPE) RETURN DATE IS
            v_fec_vencimiento DATE;
         BEGIN
            SELECT MIN(fec_vencimiento)
              INTO v_fec_vencimiento
              FROM pr_cuotas
             WHERE fec_vencimiento <= p_fec_proceso
               AND estado <> 'N'
               AND nro_cuenta = p_nro_operacion
             ORDER BY fec_vencimiento ASC;

            RETURN v_fec_vencimiento;
         EXCEPTION
            WHEN OTHERS THEN
               RETURN NULL;
         END;
         -- Obtiene el monto de la Cuota Vencida
         FUNCTION lf_obt_mto_cuo_che_ven(p_fec_proceso   IN sb_crc_operaciones_det.fecha%TYPE,
                                         p_nro_operacion IN sb_crc_operaciones_det.nro_operacion%TYPE,
                                         p_nro_cuota     IN pr_cuotas.nro_cuota%TYPE,
                                         p_nro_cheque    IN ge_che_custodias.cta_libradora%TYPE) RETURN NUMBER IS
            v_mto_cuo_vencida NUMBER;
         BEGIN
            SELECT cuota
              INTO v_mto_cuo_vencida
              FROM (SELECT nvl(SUM(nvl(sal_capital, 0)) + SUM(nvl(sal_interes, 0)) + SUM(nvl(sal_int_documentado, 0)), 0) Cuota
                       FROM pr_cuotas
                      WHERE fec_vencimiento < p_fec_proceso
                        AND estado <> 'N'
                        AND nro_cuenta = p_nro_operacion
                       -- AND nro_cuota = p_nro_cuota
                      group by nro_cuota
                      ORDER BY nro_cuota ASC)
             where rownum = 1;

            RETURN v_mto_cuo_vencida;
         EXCEPTION
            WHEN OTHERS THEN
               RETURN 0;
         END;
       -- Obtiene el monto de la Cuota Vencida
       FUNCTION lf_obt_can_cuo
       (
          p_fec_proceso   IN sb_crc_operaciones_det.fecha%TYPE,
          p_nro_operacion IN sb_crc_operaciones_det.nro_operacion%TYPE,
          p_nro_cuota     IN pr_cuotas.nro_cuota%TYPE,
          p_nro_cheque    IN ge_che_custodias.cta_libradora%TYPE
       ) RETURN NUMBER IS
          v_can_cuotas NUMBER;
       BEGIN
          SELECT count(*)
            INTO v_can_cuotas
            FROM pr_cuotas
           WHERE fec_vencimiento < p_fec_proceso
             AND estado <> 'N'
             AND nro_cuenta = p_nro_operacion;
          IF v_can_cuotas = 0 THEN v_can_cuotas := 1;  END IF;
          RETURN v_can_cuotas;
       EXCEPTION
          WHEN OTHERS THEN
             RETURN 1;
       END;

      BEGIN
         p_fec_vto_cuota       := lf_obt_fec_vto_cheque(p_fec_proceso, p_nro_operacion, p_nro_cuota, p_nro_cheque);
         p_fec_pri_cuo_vencida := lf_obt_fec_pri_cuo_che_ven(p_fec_proceso, p_nro_operacion, p_nro_cuota, p_nro_cheque);
         p_mto_cuo_vencida     := lf_obt_mto_cuo_che_ven(p_fec_proceso, p_nro_operacion, p_nro_cuota, p_nro_cheque);
         p_can_cuo_vencida     := lf_obt_can_cuo(p_fec_proceso, p_nro_operacion, p_nro_cuota, p_nro_cheque);
      EXCEPTION
         WHEN OTHERS THEN
            p_fec_vto_cuota       := NULL;
            p_fec_pri_cuo_vencida := NULL;
            p_mto_cuo_vencida     := NULL;
      END;
      PROCEDURE lp_obt_dat_libradores
      (
         p_nro_operacion IN sb_crc_operaciones_det.nro_operacion%TYPE,
         p_cod_persona   IN sb_crc_operaciones_det.cod_persona%TYPE,
         p_nro_cuota     OUT pr_cuotas.nro_cuota%TYPE,
         p_sal_capital   OUT pr_cta_prestamos.sal_capital%TYPE,
         p_cantidad      OUT pr_cta_prestamos.can_cuotas%TYPE
      ) IS
      BEGIN
         SELECT COUNT(*)
           INTO p_cantidad
           FROM (SELECT CASE
                        WHEN v_cod_entidad = 2080 AND pr.fec_inicio >= v_fec_imp_cta_lib THEN
                         x.cta_libradora
                        ELSE
                         z.cod_persona
                        END,
                        SUM(nvl(pag_gen.fu_con_mon_a_moneda(pr.cod_moneda, pag_gen.fu_obt_mon_local,
                                                            nvl(t.monto, 0), NULL), 0)) sal_capital,
                        MAX(t.nro_cuota)
                   FROM ge_che_custodias  t,
                        pr_rel_chq_lib    x,
                        pr_chq_libradores y,
                        ba_personas       z,
                        pr_cta_prestamos  pr,
                        pr_cuotas         cuo
                  WHERE x.cod_banco = t.cod_banco
                    AND x.nro_cheque = t.nro_cheque
                    AND x.cta_libradora = t.cta_libradora
                    AND t.estado IN ('C', 'A', 'B') -- a = en compensacion / b = devuelto / c = custodio -
                    AND y.nro_documento = x.nro_documento
                    AND y.cod_tip_documento = x.cod_tip_documento
                    AND z.nro_documento = x.nro_documento
                    AND z.cod_tip_documento = x.cod_tip_documento
                    AND t.nro_referencia = pr.nro_cuenta
                    AND cuo.nro_cuenta = pr.nro_cuenta
                    AND cuo.nro_cuota = t.nro_cuota
                    AND pr.nro_cuenta = p_nro_operacion
                    AND cuo.estado <> 'N'
                    AND pr.est_batch <> 'N'
                       --no informar descuento de cheques propios.
                    AND NOT EXISTS (SELECT 1
                           FROM ge_cta_clientes s
                          WHERE s.nro_cuenta = pr.nro_cuenta
                            AND s.cod_persona = z.cod_persona
                            AND s.relacion = 'P' and s.cod_modalidad <> 622/*613*/)
                     AND v_inc_emisores = 'S'
                  GROUP BY CASE
                        WHEN v_cod_entidad = 2080 AND pr.fec_inicio >= v_fec_imp_cta_lib THEN
                         x.cta_libradora
                        ELSE
                         z.cod_persona
                        END
                 UNION ALL
                 SELECT p.cod_persona,
                        SUM(nvl((pag_gen.fu_con_mon_a_moneda(pr.cod_moneda, pag_gen.fu_obt_mon_local,
                                                             nvl(d.monto, 0), NULL)), 0)) sal_capital,
                        MAX(d.nro_cuota)
                   FROM pr_documentos d, ba_personas p, pr_cta_prestamos pr, pr_cuotas cuo
                  WHERE d.estado = 'C'
                    AND p.cod_tip_documento = d.cod_tip_documento
                    AND p.nro_documento = d.nro_documento
                    AND d.nro_referencia = pr.nro_cuenta
                    AND pr.nro_cuenta = p_nro_operacion
                    AND cuo.nro_cuenta = pr.nro_cuenta
                    AND cuo.nro_cuota = d.nro_cuota
                    AND pr.est_batch <> 'N'
                    AND cuo.estado <> 'N'
                    AND v_inc_emisores = 'S'
                  GROUP BY p.cod_persona);
         -----------modificado para que me traiga el saldos capital /*t.monto*/cuo.mto_capital
         SELECT SUM(nvl(pag_gen.fu_con_mon_a_moneda(pr.cod_moneda, pag_gen.fu_obt_mon_local,
                                                    nvl(/*t.monto*/cuo.mto_capital, 0), NULL), 0)) sal_capital,
                MAX(t.nro_cuota)
           INTO p_sal_capital, p_nro_cuota
           FROM ge_che_custodias  t,
                pr_rel_chq_lib    x,
                pr_chq_libradores y,
                ba_personas       z,
                pr_cta_prestamos  pr,
                pr_cuotas         cuo
          WHERE x.cod_banco = t.cod_banco
            AND x.nro_cheque = t.nro_cheque
            AND x.cta_libradora = t.cta_libradora
            AND t.estado IN ('C', 'A', 'B') -- a = en compensacion / b = devuelto / c = custodio -
            AND y.nro_documento = x.nro_documento
            AND y.cod_tip_documento = x.cod_tip_documento
            AND z.nro_documento = x.nro_documento
            AND z.cod_tip_documento = x.cod_tip_documento
            AND t.nro_referencia = pr.nro_cuenta
            AND cuo.nro_cuenta = pr.nro_cuenta
            AND cuo.nro_cuota = t.nro_cuota
            AND pr.nro_cuenta = p_nro_operacion
            AND z.cod_persona = p_cod_persona
            AND cuo.estado <> 'N'
            AND pr.est_batch <> 'N'
               --no informar descuento de cheques propios.
            AND NOT EXISTS (SELECT 1
                   FROM ge_cta_clientes s
                  WHERE s.nro_cuenta = pr.nro_cuenta
                    AND s.cod_persona = z.cod_persona
                    AND s.relacion = 'P' and s.cod_modalidad <> 622/*613*/)
          AND v_inc_emisores = 'S'
          GROUP BY z.cod_persona
         UNION ALL
         ----modificado para que me traiga el saldos capital /*t.monto*/cuo.mto_capital
         SELECT SUM(nvl((pag_gen.fu_con_mon_a_moneda(pr.cod_moneda, pag_gen.fu_obt_mon_local,
                                                     nvl(/*d.monto*/cuo.mto_capital, 0), NULL)), 0)) sal_capital,
                MAX(d.nro_cuota)
           FROM pr_documentos d, ba_personas p, pr_cta_prestamos pr, pr_cuotas cuo
          WHERE d.estado = 'C'
            AND p.cod_tip_documento = d.cod_tip_documento
            AND p.nro_documento = d.nro_documento
            AND d.nro_referencia = pr.nro_cuenta
            AND pr.nro_cuenta = p_nro_operacion
            AND cuo.nro_cuenta = pr.nro_cuenta
            AND cuo.nro_cuota = d.nro_cuota
            AND pr.est_batch <> 'N'
            AND p.cod_persona = p_cod_persona
            AND cuo.estado <> 'N'
            AND v_inc_emisores = 'S'
          GROUP BY p.cod_persona;
      EXCEPTION
         WHEN OTHERS THEN
            p_nro_cuota   := NULL;
            p_sal_capital := NULL;
            p_cantidad    := NULL;
      END;

      --- Obtiene los saldos de prestamos para Descuentos de Documentos y Descuentos de cheques
      PROCEDURE lp_obt_dat_cheque(p_nro_cuenta             IN pr_cta_prestamos.nro_cuenta%TYPE,
                                  p_nro_operacion          IN sb_crc_operaciones_det.nro_operacion%TYPE,
                                  p_nro_cuota              IN pr_cuotas.nro_cuota%TYPE,
                                  p_nro_cheque             IN ge_che_custodias.cta_libradora%TYPE,
                                  p_cod_persona            IN ge_cta_clientes.cod_persona%TYPE,
                                  p_fec_operacion          IN pr_cta_prestamos.fec_inicio%TYPE,
                                  p_est_batch              OUT pr_cta_prestamos.est_batch%TYPE,
                                  p_estado                 OUT pr_cta_prestamos.estado%TYPE,
                                  p_sal_capital            OUT pr_cta_prestamos.sal_capital%TYPE,
                                  p_val_int_devengar       OUT pr_cta_prestamos.val_int_devengar%TYPE,
                                  p_dev_cobrado            OUT pr_cta_prestamos.dev_acumulado%TYPE,
                                  p_dev_suspenso           OUT pr_cta_prestamos.dev_suspenso%TYPE,
                                  p_can_cuo_pagadas        OUT pr_cta_prestamos.can_cuo_pagadas%TYPE,
                                  p_dia_atraso             OUT pr_cta_prestamos.dia_atraso%TYPE,
                                  p_cod_modalidad          OUT pr_cta_prestamos.cod_modalidad%TYPE,
                                  p_cta_con_dev_cobrado    OUT sb_crc_saldos_det.rub_con_int_dev_cobrado%TYPE,
                                  p_tip_operacion          OUT pr_cta_prestamos.tipo%TYPE,
                                  p_cta_con_dev_no_cobrado OUT sb_crc_saldos_det.rub_con_int_dev_cobrado%TYPE,
                                  p_dev_no_cobrado         OUT pr_cta_prestamos.dev_acumulado%TYPE,
                                  p_rub_con_capital        OUT sb_crc_saldos_det.rub_con_int_dev_cobrado%TYPE,
                                  p_rub_con_int_devengar   OUT sb_crc_saldos_det.rub_con_int_dev_cobrado%TYPE,
                                  p_rub_con_dev_suspenso   OUT sb_crc_saldos_det.rub_con_int_dev_cobrado%TYPE,
                                  p_tas_efectiva           OUT sb_crc_saldos_det.tas_efectiva%TYPE,
                                  p_can_cuotas             OUT pr_cta_prestamos.can_cuotas%TYPE

                                  ) IS
         v_cod_moneda          pr_cta_prestamos.cod_moneda%TYPE;
         v_tip_interes         pr_cta_prestamos.tip_interes%TYPE;
         v_fec_vencimiento     pr_cta_prestamos.fec_vencimiento%TYPE;
         v_fec_ini_prestamo    pr_cta_prestamos.fec_inicio%TYPE;
         v_cod_sec_credito     pr_cta_prestamos.cod_sec_credito%TYPE;
         v_cod_sec_contable    ge_clientes.cod_sec_contable%TYPE;
         v_cod_tip_deudor      ge_clientes.cod_tip_deudor%TYPE;
         v_residente           ge_clientes.residente%TYPE;
         v_cod_transaccion     ge_transacciones.cod_transaccion%TYPE;
         v_cod_sit_contable    ge_cuentas.cod_sit_contable%TYPE;
         v_cod_tra_interes     ge_transacciones.cod_transaccion%TYPE;
         v_cta_con_dev_cobrado cb_rubros.cod_rubro%TYPE;
         v_tip_renovacion      pr_cta_prestamos.tip_renovacion%TYPE;
         v_nro_cuota           pr_cuotas.nro_cuota%TYPE;

      BEGIN
        -- v_existe := lf_ver_exi_saldos(p_nro_operacion, p_fec_operacion); -- existe por operacion cta+cuo+cheque
         SELECT (nvl(p.sal_capital, 0)) sal_cap_batch,
                ((nvl(p.mto_interes, 0) + nvl(p.mto_int_documentado, 0)) - nvl(p.dev_acumulado, 0)),
                (nvl((nvl(p.dev_acumulado, 0) - (nvl(p.dev_suspenso, 0) + nvl(p.dev_no_cobrado, 0))), 0)),
                (nvl(p.dev_suspenso, 0)), (nvl(p.dev_no_cobrado, 0)),
                decode(a.estado, 'N', 0, nvl(a.dia_atraso, 0)) dia_atraso, a.can_cuo_pagadas, a.estado, a.cod_modalidad,
                a.tipo, a.cod_moneda, a.tip_interes, a.fec_vencimiento, a.fec_inicio, a.cod_sec_credito,
                b.cod_sec_contable, b.cod_tip_deudor, b.residente, a.can_cuotas, a.tip_renovacion
           INTO p_sal_capital, p_val_int_devengar, p_dev_cobrado, p_dev_suspenso, p_dev_no_cobrado, p_dia_atraso,
                p_can_cuo_pagadas, p_estado, p_cod_modalidad, p_tip_operacion, v_cod_moneda, v_tip_interes,
                v_fec_vencimiento, v_fec_ini_prestamo, v_cod_sec_credito, v_cod_sec_contable, v_cod_tip_deudor,
                v_residente, p_can_cuotas, v_tip_renovacion
           FROM pr_cta_prestamos a, ge_clientes b, pr_cuotas p, ba_personas s--, pr_rel_chq_lib l, ge_che_custodias ch
          WHERE a.nro_cuenta = p.nro_cuenta
            AND b.cod_persona(+) = s.cod_persona
            AND a.nro_cuenta = p_nro_cuenta
            AND p.nro_Cuota = p_nro_cuota
            AND p.nro_cuenta = p_nro_cuenta
            AND s.cod_persona = p_cod_persona
            AND p.estado <> 'N'
             AND (a.estado <> 'N' /*OR
                (a.estado = 'N' --Canceladas en el mes de informe. FIELDESK 5171 VGONZALEZ 20/12/2021
                AND nvl(a.sal_capital, 0) + nvl(a.sal_int_adelantado, 0) = 0 AND
                (fec_cancelacion BETWEEN v_fec_inicio AND v_fec_fin OR fec_cancelacion IS NULL) AND v_Existe = 'S')*/)
            AND NOT EXISTS (SELECT 1
                   FROM ge_par_dinamicos p
                  WHERE p.parametro = 'SIB_CRC_MAD_EXC_ARCHIVO'
                    AND p.cod_modalidad = a.cod_modalidad
                    AND nvl(p.val_parametro, 'N') = 'S');

         v_cotizacion           := nvl(fug_obt_cotizacion(v_cod_moneda, v_fec_fin), 1);
         p_dev_no_cobrado       := round(p_dev_no_cobrado * v_cotizacion, v_redondeo);
         p_rub_con_capital      := pab_asi.fu_obt_rub_contable(p_nro_cuenta, 'C');
         p_rub_con_int_devengar := pab_asi.fu_obt_rub_contable(p_nro_cuenta, 'A');
         p_rub_con_dev_suspenso := pab_asi.fu_obt_rub_contable(p_nro_cuenta, 'S');
         p_tas_efectiva         := nvl(fus_obt_tas_efectiva(p_nro_cuenta), 0);
         IF p_estado = 'C' AND v_tip_interes = 'A' THEN
            v_cod_transaccion := 806;
         ELSIF p_estado = 'V' AND v_tip_interes = 'A' THEN
            v_cod_transaccion := 814;
         ELSIF p_estado = 'G' AND v_tip_interes = 'A' THEN
            v_cod_transaccion := 818;
         ELSIF p_estado IN ('M', 'I') AND v_tip_interes = 'A' THEN
            v_cod_transaccion := 826;
         END IF;
     --    IF p_dev_cobrado <> 0 THEN
             v_cta_con_dev_cobrado := IT.pas_cri.fu_obt_cod_rubro(p_nro_cuenta,null,null, v_cod_transaccion, null,null,null,null,null, 'C',null,p_estado,null,null,null,null,null);

            IF v_cta_con_dev_cobrado IS NULL THEN
               IF p_estado IN ('C', 'A') THEN
                  v_cod_transaccion := 806;
               ELSIF p_estado = 'V' THEN
                  v_cod_transaccion := 814;
               ELSIF p_estado = 'G' THEN
                  v_cod_transaccion := 818;
               ELSIF p_estado IN ('M', 'I') THEN
                  v_cod_transaccion := 826;
               END IF;

               v_cta_con_dev_cobrado := IT.pas_cri.fu_obt_cod_rubro(p_nro_cuenta,null,null, v_cod_transaccion, null,null,null,null,null, 'C',null,p_estado,null,null,null,null,null);

            END IF;
       --  END IF;
         IF p_estado = 'C' THEN
            v_cod_tra_interes := 901;
         ELSIF p_estado IN ('M', 'I', 'V', 'G') THEN
            p_cta_con_dev_cobrado := NULL;
            p_dev_cobrado         := 0;
         END IF;
         IF p_dev_no_cobrado > 0 THEN
            p_cta_con_dev_no_cobrado := lf_obt_rub_padre(v_cta_con_dev_cobrado);
         END IF;
         IF p_dev_cobrado > 0 THEN
            p_cta_con_dev_cobrado := IT.pas_cri.fu_obt_rub_resultado(p_nro_cuenta,
                                                                  v_cod_tra_interes,
                                                                  NULL,
                                                                  'C',
                                                                  p_estado,
                                                                  v_tip_renovacion,
                                                                  v_tip_interes,
                                                                  p_tip_operacion,
                                                                  NULL,
                                                                  v_cod_moneda);
            IF substr(p_cta_con_dev_cobrado, 1, 2) NOT IN (61, 71) THEN
               p_cta_con_dev_cobrado := IT.pas_cri.fu_obt_rub_resultado(p_nro_cuenta,
                                                                     908,
                                                                     NULL,
                                                                     'C',
                                                                     p_estado,
                                                                     v_tip_renovacion,
                                                                     v_tip_interes,
                                                                     p_tip_operacion,
                                                                     NULL,
                                                                     v_cod_moneda);
            END IF;
         END IF;
      EXCEPTION
         WHEN no_data_found THEN
            NULL;
         WHEN OTHERS THEN
            p_est_batch        := NULL;
            p_estado           := NULL;
            p_sal_capital      := 0;
            p_val_int_devengar := 0;
            p_dev_cobrado      := 0;
            p_dev_suspenso     := 0;
            p_can_cuo_pagadas  := 0;
            p_dia_atraso       := 0;
      END;
      --- Para obtener los datos de descuento de documentos

      --- Obtiene los saldos de prestamos para Descuentos de Documentos y Descuentos de cheques
      PROCEDURE lp_obt_dat_documento(p_nro_cuenta             IN pr_cta_prestamos.nro_cuenta%TYPE,
                                     p_nro_operacion          IN sb_crc_operaciones_det.nro_operacion%TYPE,
                                     p_nro_cuota              IN pr_cuotas.nro_cuota%TYPE,
                                     p_documento              IN pr_documentos.documento%TYPE,
                                     p_cod_persona            IN ge_cta_clientes.cod_persona%TYPE,
                                     p_fec_operacion          IN pr_cta_prestamos.fec_inicio%TYPE,
                                     p_est_batch              OUT pr_cta_prestamos.est_batch%TYPE,
                                     p_estado                 OUT pr_cta_prestamos.estado%TYPE,
                                     p_sal_capital            OUT pr_cta_prestamos.sal_capital%TYPE,
                                     p_val_int_devengar       OUT pr_cta_prestamos.val_int_devengar%TYPE,
                                     p_dev_cobrado            OUT pr_cta_prestamos.dev_acumulado%TYPE,
                                     p_dev_suspenso           OUT pr_cta_prestamos.dev_suspenso%TYPE,
                                     p_can_cuo_pagadas        OUT pr_cta_prestamos.can_cuo_pagadas%TYPE,
                                     p_dia_atraso             OUT pr_cta_prestamos.dia_atraso%TYPE,
                                     p_cod_modalidad          OUT pr_cta_prestamos.cod_modalidad%TYPE,
                                     p_cta_con_dev_cobrado    OUT sb_crc_saldos_det.rub_con_int_dev_cobrado%TYPE,
                                     p_tip_operacion          OUT pr_cta_prestamos.tipo%TYPE,
                                     p_cta_con_dev_no_cobrado OUT sb_crc_saldos_det.rub_con_int_dev_cobrado%TYPE,
                                     p_dev_no_cobrado         OUT pr_cta_prestamos.dev_acumulado%TYPE,
                                     p_rub_con_capital        OUT sb_crc_saldos_det.rub_con_int_dev_cobrado%TYPE,
                                     p_rub_con_int_devengar   OUT sb_crc_saldos_det.rub_con_int_dev_cobrado%TYPE,
                                     p_rub_con_dev_suspenso   OUT sb_crc_saldos_det.rub_con_int_dev_cobrado%TYPE,
                                     p_tas_efectiva           OUT sb_crc_saldos_det.tas_efectiva%TYPE,
                                     p_can_cuotas             OUT pr_cta_prestamos.can_cuotas%TYPE

                                     ) IS
         v_cod_moneda          pr_cta_prestamos.cod_moneda%TYPE;
         v_tip_interes         pr_cta_prestamos.tip_interes%TYPE;
         v_fec_vencimiento     pr_cta_prestamos.fec_vencimiento%TYPE;
         v_fec_ini_prestamo    pr_cta_prestamos.fec_inicio%TYPE;
         v_cod_sec_credito     pr_cta_prestamos.cod_sec_credito%TYPE;
         v_cod_sec_contable    ge_clientes.cod_sec_contable%TYPE;
         v_cod_tip_deudor      ge_clientes.cod_tip_deudor%TYPE;
         v_residente           ge_clientes.residente%TYPE;
         v_cod_transaccion     ge_transacciones.cod_transaccion%TYPE;
         v_cod_sit_contable    ge_cuentas.cod_sit_contable%TYPE;
         v_cod_tra_interes     ge_transacciones.cod_transaccion%TYPE;
         v_cta_con_dev_cobrado cb_rubros.cod_rubro%TYPE;
         v_tip_renovacion      pr_cta_prestamos.tip_renovacion%TYPE;
         v_nro_cuota           pr_cuotas.nro_cuota%TYPE;

      BEGIN
        -- v_existe := lf_ver_exi_saldos(p_nro_operacion, p_fec_operacion); -- existe por operacion cta+cuo+cheque
         SELECT (nvl(p.sal_capital, 0)) sal_cap_batch,
                ((nvl(p.mto_interes, 0) + nvl(p.mto_int_documentado, 0)) - nvl(p.dev_acumulado, 0)),
                (nvl((nvl(p.dev_acumulado, 0) - (nvl(p.dev_suspenso, 0) + nvl(p.dev_no_cobrado, 0))), 0)),
                (nvl(p.dev_suspenso, 0)), (nvl(p.dev_no_cobrado, 0)), a.can_cuo_pagadas, a.estado,
                decode(a.estado, 'N', 0, nvl(a.dia_atraso, 0)) dia_atraso, a.cod_modalidad, a.tipo, a.cod_moneda,
                a.tip_interes, a.fec_vencimiento, a.fec_inicio, a.cod_sec_credito, b.cod_sec_contable, b.cod_tip_deudor,
                b.residente, a.can_cuotas, a.tip_renovacion
           INTO p_sal_capital, p_val_int_devengar, p_dev_cobrado, p_dev_suspenso, p_dev_no_cobrado, p_can_cuo_pagadas,
                p_estado, p_dia_atraso, p_cod_modalidad, p_tip_operacion, v_cod_moneda, v_tip_interes, v_fec_vencimiento,
                v_fec_ini_prestamo, v_cod_sec_credito, v_cod_sec_contable, v_cod_tip_deudor, v_residente, p_can_cuotas,
                v_tip_renovacion
           FROM pr_cta_prestamos a, ge_clientes b, pr_cuotas p, ba_personas s--, pr_documentos ch
          WHERE a.nro_cuenta = p.nro_cuenta
            AND b.cod_persona(+) = s.cod_persona
            AND a.nro_cuenta = pae_uti.fu_obt_valor(p_nro_cuenta, 1)
            AND p.nro_cuota = p_nro_cuota
            AND s.cod_persona = p_cod_persona
            AND p.nro_cuenta = p_nro_cuenta
            AND p.estado  <> 'N'
            AND (a.estado <> 'N' /*OR
                (a.estado = 'N' --Canceladas en el mes de informe. FIELDESK 5171 VGONZALEZ 20/11/2021
                AND nvl(a.sal_capital, 0) + nvl(a.sal_int_adelantado, 0) = 0 AND
                (fec_cancelacion BETWEEN v_fec_inicio AND v_fec_fin OR fec_cancelacion IS NULL) AND v_existe = 'S')*/)
            AND NOT EXISTS (SELECT 1
                   FROM ge_par_dinamicos p
                  WHERE p.parametro = 'SIB_CRC_MAD_EXC_ARCHIVO'
                    AND p.cod_modalidad = a.cod_modalidad
                    AND nvl(p.val_parametro, 'N') = 'S');

         --- si es moneda extranjera
         v_cotizacion           := nvl(fug_obt_cotizacion(v_cod_moneda, v_fec_fin), 1);
         p_dev_no_cobrado       := round(p_dev_no_cobrado * v_cotizacion, v_redondeo);
         p_rub_con_capital      := pab_asi.fu_obt_rub_contable(p_nro_cuenta, 'C');
         p_rub_con_int_devengar := pab_asi.fu_obt_rub_contable(p_nro_cuenta, 'A');
         p_rub_con_dev_suspenso := pab_asi.fu_obt_rub_contable(p_nro_cuenta, 'S');
         p_tas_efectiva         := nvl(fus_obt_tas_efectiva(p_nro_cuenta), 0);
         IF p_estado = 'C' AND v_tip_interes = 'A' THEN
            v_cod_transaccion := 806;
         ELSIF p_estado = 'V' AND v_tip_interes = 'A' THEN
            v_cod_transaccion := 814;
         ELSIF p_estado = 'G' AND v_tip_interes = 'A' THEN
            v_cod_transaccion := 818;
         ELSIF p_estado IN ('M', 'I') AND v_tip_interes = 'A' THEN
            v_cod_transaccion := 826;
         END IF;

          v_cta_con_dev_cobrado := IT.pas_cri.fu_obt_cod_rubro(p_nro_cuenta,null,null, v_cod_transaccion, null,null,null,null,null, 'C',null,p_estado,null,null,null,null,null);

         IF v_cta_con_dev_cobrado IS NULL THEN
            IF p_estado IN ('C', 'A') THEN
               v_cod_transaccion := 806;
            ELSIF p_estado = 'V' THEN
               v_cod_transaccion := 814;
            ELSIF p_estado = 'G' THEN
               v_cod_transaccion := 818;
            ELSIF p_estado IN ('M', 'I') THEN
               v_cod_transaccion := 826;
            END IF;
         END IF;
         v_cta_con_dev_cobrado := IT.pas_cri.fu_obt_cod_rubro(p_nro_cuenta,null,null, v_cod_transaccion, null,null,null,null,null, 'C',null,p_estado,null,null,null,null,null);

         IF p_estado = 'C' THEN
            v_cod_tra_interes := 901;
         ELSIF p_estado IN ('M', 'I', 'V', 'G') THEN
            p_cta_con_dev_cobrado := NULL;
            p_dev_cobrado         := 0;
         END IF;
         IF p_dev_no_cobrado > 0 THEN
            p_cta_con_dev_no_cobrado := lf_obt_rub_padre(v_cta_con_dev_cobrado);
         END IF;
        -- IF p_dev_cobrado > 0 THEN
            p_cta_con_dev_cobrado := IT.pas_cri.fu_obt_rub_resultado(p_nro_cuenta,
                                                                  v_cod_tra_interes,
                                                                  NULL,
                                                                  'C',
                                                                  p_estado,
                                                                  v_tip_renovacion,
                                                                  v_tip_interes,
                                                                  p_tip_operacion,
                                                                  NULL,
                                                                  v_cod_moneda);
            IF substr(p_cta_con_dev_cobrado, 1, 2) NOT IN (61, 71) THEN
               p_cta_con_dev_cobrado := IT.pas_cri.fu_obt_rub_resultado(p_nro_cuenta,
                                                                     908,
                                                                     NULL,
                                                                     'C',
                                                                     p_estado,
                                                                     v_tip_renovacion,
                                                                     v_tip_interes,
                                                                     p_tip_operacion,
                                                                     NULL,
                                                                     v_cod_moneda);
            END IF;
        -- END IF;
      EXCEPTION
         WHEN no_data_found THEN
            NULL;
         WHEN OTHERS THEN
            p_est_batch        := NULL;
            p_estado           := NULL;
            p_sal_capital      := 0;
            p_val_int_devengar := 0;
            p_dev_cobrado      := 0;
            p_dev_suspenso     := 0;
            p_can_cuo_pagadas  := 0;
            p_dia_atraso       := 0;
      END;
      -- Obtiene datos correspondientes a los saldos
      PROCEDURE lp_obt_dat_cuentas(p_fec_proceso         IN sb_crc_operaciones_det.fecha%TYPE,
                                   p_nro_operacion       IN sb_crc_operaciones_det.nro_operacion%TYPE,
                                   p_cod_modulo          IN sb_crc_operaciones_det.cod_modulo%TYPE,
                                   p_fec_vto_cuota       OUT pr_cuotas.fec_vencimiento%TYPE,
                                   p_fec_pri_cuo_vencida OUT pr_cuotas.fec_vencimiento%TYPE,
                                   p_mto_cuo_vencida     OUT pr_cuotas.mto_capital%TYPE

                                   ) IS
         -- Obtiene la fecha de vencimiento de la siguiente cuota
         FUNCTION lf_obt_fec_vto_cuota(p_fec_proceso   IN sb_crc_operaciones_det.fecha%TYPE,
                                       p_nro_operacion IN sb_crc_operaciones_det.nro_operacion%TYPE,
                                       p_cod_modulo    IN sb_crc_operaciones_det.cod_modulo%TYPE) RETURN DATE IS
            v_fec_vencimiento DATE;
         BEGIN
            IF p_cod_modulo = 6 THEN
               SELECT MIN(fec_vencimiento)
                 INTO v_fec_vencimiento
                 FROM pr_cuotas
                WHERE estado <> 'N'
                  AND nro_cuota > 0
                  AND nro_cuenta = pae_uti.fu_obt_valor(p_nro_operacion, 1)
                ORDER BY fec_vencimiento ASC;
            ELSIF p_cod_modulo = 10 THEN
               SELECT MIN(fec_vencimiento)
                 INTO v_fec_vencimiento
                 FROM md_doc_detalles
                WHERE fec_vencimiento > p_fec_proceso
                  AND estado <> 'N'
                  AND nro_cuota > 0
                  AND nro_cuenta = p_nro_operacion
                ORDER BY fec_vencimiento ASC;
            END IF;
            RETURN v_fec_vencimiento;
         EXCEPTION
            WHEN OTHERS THEN
               RETURN NULL;
         END;
         -- Obtiene la fecha de vencimiento de la primera cuota impaga
         FUNCTION lf_obt_fec_pri_cuo_vencida(p_fec_proceso   IN sb_crc_operaciones_det.fecha%TYPE,
                                             p_nro_operacion IN sb_crc_operaciones_det.nro_operacion%TYPE,
                                             p_cod_modulo    IN sb_crc_operaciones_det.cod_modulo%TYPE) RETURN DATE IS
            v_fec_vencimiento DATE;
         BEGIN
            IF p_cod_modulo = 6 THEN
               SELECT MIN(fec_vencimiento)
                 INTO v_fec_vencimiento
                 FROM pr_cuotas
                WHERE fec_vencimiento <= p_fec_proceso
                  AND estado <> 'N'
                  AND nro_cuenta = pae_uti.fu_obt_valor(p_nro_operacion, 1)
                  AND nro_cuota > 0
                ORDER BY fec_vencimiento ASC;
            ELSIF p_cod_modulo = 10 THEN
               SELECT MIN(fec_vencimiento)
                 INTO v_fec_vencimiento
                 FROM md_doc_detalles
                WHERE fec_vencimiento < p_fec_proceso
                  AND estado <> 'N'
                  AND nro_cuenta = p_nro_operacion
                  AND nro_cuota > 0
                ORDER BY fec_vencimiento ASC;
            END IF;
            RETURN v_fec_vencimiento;
         EXCEPTION
            WHEN OTHERS THEN
               RETURN NULL;
         END;
         -- Obtiene el monto de la Cuota Vencida
         FUNCTION lf_obt_mto_cuo_vencida(p_fec_proceso   IN sb_crc_operaciones_det.fecha%TYPE,
                                         p_nro_operacion IN sb_crc_operaciones_det.nro_operacion%TYPE,
                                         p_cod_modulo    IN sb_crc_operaciones_det.cod_modulo%TYPE) RETURN NUMBER IS
            v_mto_cuo_vencida NUMBER;
         BEGIN
            IF p_cod_modulo = 6 THEN
               SELECT nvl(SUM(nvl(sal_capital, 0)) + SUM(nvl(sal_interes, 0)) + SUM(nvl(sal_int_documentado, 0)), 0)
                 INTO v_mto_cuo_vencida
                 FROM pr_cuotas
                WHERE fec_vencimiento < p_fec_proceso
                  AND estado <> 'N'
                  AND nro_cuenta = pae_uti.fu_obt_valor(p_nro_operacion, 1)
                ORDER BY fec_vencimiento ASC;
            ELSIF p_cod_modulo = 10 THEN
               SELECT nvl(SUM(nvl(sal_capital, 0)) + SUM(nvl(sal_interes, 0)), 0)
                 INTO v_mto_cuo_vencida
                 FROM md_doc_detalles
                WHERE fec_vencimiento < p_fec_proceso
                  AND estado <> 'N'
                  AND nro_cuenta = p_nro_operacion
                ORDER BY fec_vencimiento ASC;
            END IF;
            RETURN v_mto_cuo_vencida;
         EXCEPTION
            WHEN OTHERS THEN
               RETURN 0;
         END;

      BEGIN
         p_fec_vto_cuota       := lf_obt_fec_vto_cuota(p_fec_proceso, p_nro_operacion, p_cod_modulo);
         p_fec_pri_cuo_vencida := lf_obt_fec_pri_cuo_vencida(p_fec_proceso, p_nro_operacion, p_cod_modulo);
         p_mto_cuo_vencida     := lf_obt_mto_cuo_vencida(p_fec_proceso, p_nro_operacion, p_cod_modulo);
      EXCEPTION
         WHEN OTHERS THEN
            p_fec_vto_cuota       := NULL;
            p_fec_pri_cuo_vencida := NULL;
            p_mto_cuo_vencida     := NULL;
      END;
      PROCEDURE lp_obt_dat_prestamo(p_nro_cuenta             IN pr_cta_prestamos.nro_cuenta%TYPE,
                                    p_fec_operacion          IN pr_cta_prestamos.fec_inicio%TYPE,
                                    p_est_batch              OUT pr_cta_prestamos.est_batch%TYPE,
                                    p_estado                 OUT pr_cta_prestamos.estado%TYPE,
                                    p_sal_capital            OUT pr_cta_prestamos.sal_capital%TYPE,
                                    p_val_int_devengar       OUT pr_cta_prestamos.val_int_devengar%TYPE,
                                    p_dev_cobrado            OUT pr_cta_prestamos.dev_acumulado%TYPE,
                                    p_dev_suspenso           OUT pr_cta_prestamos.dev_suspenso%TYPE,
                                    p_can_cuo_pagadas        OUT pr_cta_prestamos.can_cuo_pagadas%TYPE,
                                    p_dia_atraso             OUT pr_cta_prestamos.dia_atraso%TYPE,
                                    p_cod_modalidad          OUT pr_cta_prestamos.cod_modalidad%TYPE,
                                    p_cta_con_dev_cobrado    OUT sb_crc_saldos_det.rub_con_int_dev_cobrado%TYPE,
                                    p_tip_operacion          OUT pr_cta_prestamos.tipo%TYPE,
                                    p_cta_con_dev_no_cobrado OUT sb_crc_saldos_det.rub_con_int_dev_cobrado%TYPE,
                                    p_dev_no_cobrado         OUT pr_cta_prestamos.dev_acumulado%TYPE

                                    ) IS
         v_cod_moneda          pr_cta_prestamos.cod_moneda%TYPE;
         v_tip_interes         pr_cta_prestamos.tip_interes%TYPE;
         v_fec_vencimiento     pr_cta_prestamos.fec_vencimiento%TYPE;
         v_fec_ini_prestamo    pr_cta_prestamos.fec_inicio%TYPE;
         v_cod_sec_credito     pr_cta_prestamos.cod_sec_credito%TYPE;
         v_cod_sec_contable    ge_clientes.cod_sec_contable%TYPE;
         v_cod_tip_deudor      ge_clientes.cod_tip_deudor%TYPE;
         v_residente           ge_clientes.residente%TYPE;
         v_cod_transaccion     ge_transacciones.cod_transaccion%TYPE;
         v_cod_sit_contable    ge_cuentas.cod_sit_contable%TYPE;
         v_cod_tra_interes     ge_transacciones.cod_transaccion%TYPE;
         v_cta_con_dev_cobrado cb_rubros.cod_rubro%type;
         v_tip_renovacion      pr_cta_prestamos.tip_renovacion%type;

      BEGIN
         --v_existe := lf_ver_exi_saldos(p_nro_cuenta, p_fec_operacion);
         SELECT a.est_batch, a.estado,
                CASE
                    WHEN a.est_batch <> 'N' THEN
                     decode(a.cod_modalidad,
                            671,
                            nvl(a.sal_cap_batch, 0) + nvl(a.sal_int_ade_batch, 0) + nvl(a.sal_int_batch, 0),
                            nvl(a.sal_cap_batch, 0))
                    ELSE
                     0
                 END sal_cap_batch,
                CASE
                   WHEN est_batch <> 'N' THEN
                    nvl(val_int_devengar, 0)
                   ELSE
                    0
                END,
                CASE
                    WHEN a.est_batch <> 'N' THEN
                     nvl((nvl(a.dev_acumulado, 0) - (nvl(a.dev_suspenso, 0) + nvl(a.dev_no_cobrado, 0))), 0)
                    ELSE
                     0
                 END dev_cobrado,
                CASE
                    WHEN est_batch <> 'N' THEN
                     nvl(a.dev_suspenso, 0)
                    ELSE
                     0
                 END dev_suspenso,
                 CASE WHEN a.est_batch <> 'N'
                 THEN decode(a.est_batch, 'I',(nvl(a.sal_interes, 0) + nvl(a.sal_int_adelantado, 0)),
                                                   nvl(a.dev_no_cobrado, 0))
                 ELSE
                      0
                 END dev_no_cobrado, a.can_cuo_pagadas, decode(a.estado, 'N', 0, nvl(a.dia_atraso, 0)) dia_atraso,
                a.cod_modalidad, a.tipo, a.cod_moneda, a.tip_interes, a.fec_vencimiento, a.fec_inicio, a.cod_sec_credito,
                b.cod_sec_contable, b.cod_tip_deudor, b.residente, d.cod_sit_contable, a.tip_renovacion
           INTO p_est_batch, p_estado, p_sal_capital, p_val_int_devengar, p_dev_cobrado, p_dev_suspenso,
                p_dev_no_cobrado, p_can_cuo_pagadas, p_dia_atraso, p_cod_modalidad, P_tip_operacion, v_cod_moneda,
                v_tip_interes, v_fec_vencimiento, v_fec_ini_prestamo, v_cod_sec_credito, v_cod_sec_contable,
                v_cod_tip_deudor, v_residente, v_cod_sit_contable, v_tip_renovacion
           FROM pr_cta_prestamos a, ge_cta_clientes g, ge_clientes b, ge_cuentas d
          WHERE a.nro_cuenta = p_nro_cuenta
            AND a.nro_cuenta = g.nro_cuenta
            AND b.cod_persona = g.cod_persona
            AND a.nro_cuenta = d.nro_cuenta
            AND g.relacion = 'P'
            AND (a.estado NOT IN ('N' ,'I') -- FIELDESK 5171 VGONZALEZ 20/12/2021
            /*OR (a.estado =  'N' --Canceladas en el mes de informe que no se deben excluir.
                and NVL(fug_obt_pardinamico('SB_MAD_EXC_SAL_CERO',a.cod_modulo,a.cod_modalidad),'N') = 'N'
                AND nvl(a.sal_capital, 0) + nvl(a.sal_int_adelantado, 0) = 0
                AND (fec_cancelacion BETWEEN v_fec_inicio AND v_fec_fin or fec_cancelacion is null)
                AND v_existe = 'S')
            OR (a.estado =  'N' --Canceladas e iniciadas en el mes de informe que se excluyen, pero se informan por ultima vez.
                and NVL(fug_obt_pardinamico('SB_MAD_EXC_SAL_CERO',a.cod_modulo,a.cod_modalidad),'N') = 'S'
                AND nvl(a.sal_capital, 0) + nvl(a.sal_int_adelantado, 0) = 0
                AND (fec_cancelacion BETWEEN v_fec_inicio AND v_fec_fin or fec_cancelacion is null)
                and to_char(fec_inicio,'MM/YYYY') <> to_char(fec_cancelacion,'MM/YYYY')
                AND v_existe = 'S')*/
            OR ((a.estado = 'I' AND
             to_date(fug_obt_paradicional(a.nro_cuenta, 'PRE_FEC_PAS_INCOBRABLE'), 'dd/mm/yyyy') IS NULL) OR
             (a.est_batch = 'I' AND
             to_date(fug_obt_paradicional(a.nro_cuenta, 'PRE_FEC_PAS_INCOBRABLE'), 'dd/mm/yyyy') IS NOT NULL AND
             ((v_fec_fin -
             to_date(fug_obt_paradicional(a.nro_cuenta, 'PRE_FEC_PAS_INCOBRABLE'), 'dd/mm/yyyy')) <=
             v_crc_can_dia_incobrable))))
            AND NOT EXISTS (SELECT 1
                   FROM ge_par_dinamicos p
                  WHERE p.parametro = 'SIB_CRC_MAD_EXC_ARCHIVO'
                    AND p.cod_modalidad = a.cod_modalidad
                    AND nvl(p.val_parametro, 'N') = 'S');
         IF p_estado = 'C' AND v_tip_interes = 'V' THEN
            v_cod_transaccion := 802;
         ELSIF p_estado = 'C' AND v_tip_interes = 'A' THEN
            v_cod_transaccion := 806;
         ELSIF p_estado = 'V' AND v_tip_interes = 'V' THEN
            v_cod_transaccion := 817;
         ELSIF p_estado = 'V' AND v_tip_interes = 'A' THEN
            v_cod_transaccion := 814;
         ELSIF p_estado = 'G' AND v_tip_interes = 'V' THEN
            v_cod_transaccion := 825;
         ELSIF p_estado = 'G' AND v_tip_interes = 'A' THEN
            v_cod_transaccion := 818;
         ELSIF p_estado IN ('M', 'I') AND v_tip_interes = 'V' THEN
            v_cod_transaccion := 828;
         ELSIF p_estado IN ('M', 'I') AND v_tip_interes = 'A' THEN
            v_cod_transaccion := 826;
         END IF;

          v_cta_con_dev_cobrado := IT.pas_cri.fu_obt_cod_rubro(p_nro_cuenta,null,null, v_cod_transaccion, null,null,null,null,null, 'C',null,p_estado,NULL,NULL,NULL,NULL,v_cod_sec_credito);

       IF v_cta_con_dev_cobrado IS NULL THEN
            IF p_estado IN ('C', 'A') THEN
               v_cod_transaccion := 806;
            ELSIF p_estado = 'V' THEN
               v_cod_transaccion := 814;
            ELSIF p_estado = 'G' THEN
               v_cod_transaccion := 818;
            ELSIF p_estado IN ('M', 'I') THEN
               v_cod_transaccion := 826;
            END IF;
         END IF;
          v_cta_con_dev_cobrado := IT.pas_cri.fu_obt_cod_rubro(p_nro_cuenta,null,null, v_cod_transaccion, null,null,null,null,null, 'C',null,p_estado,NULL,NULL,NULL,NULL,v_cod_sec_credito);

         IF p_estado = 'C' THEN
            v_cod_tra_interes := 901;
         ELSIF p_estado IN ('M', 'I', 'V', 'G') THEN
            p_cta_con_dev_cobrado := NULL;
            p_dev_cobrado         := 0;
         END IF;
         IF p_dev_no_cobrado > 0 THEN
            p_cta_con_dev_no_cobrado := lf_obt_rub_padre(v_cta_con_dev_cobrado);
         END IF;
         IF p_dev_cobrado > 0 THEN
            p_cta_con_dev_cobrado := IT.pas_cri.fu_obt_rub_resultado(p_nro_cuenta,
                                                                  v_cod_tra_interes,
                                                                  NULL,
                                                                  'C',
                                                                  p_estado,
                                                                  v_tip_renovacion,
                                                                  v_tip_interes,
                                                                  p_tip_operacion,
                                                                  v_cod_sec_credito,
                                                                  v_cod_moneda);
            IF SUBSTR(p_cta_con_dev_cobrado, 1, 2) NOT IN (61, 71) THEN
               p_cta_con_dev_cobrado := IT.pas_cri.fu_obt_rub_resultado(p_nro_cuenta,
                                                                     908,
                                                                     NULL,
                                                                     'C',
                                                                     p_estado,
                                                                     v_tip_renovacion,
                                                                     v_tip_interes,
                                                                     p_tip_operacion,
                                                                     v_cod_sec_credito,
                                                                     v_cod_moneda);
            END IF;
         END IF;
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            NULL;
         WHEN OTHERS THEN
            p_est_batch        := NULL;
            p_estado           := NULL;
            p_sal_capital      := 0;
            p_val_int_devengar := 0;
            p_dev_cobrado      := 0;
            p_dev_suspenso     := 0;
            p_can_cuo_pagadas  := 0;
            p_dia_atraso       := 0;
      END;
      FUNCTION lf_obt_int_dev_cda(p_nro_cuenta ah_cupones.nro_cuenta%TYPE) RETURN NUMBER IS
         v_mto_interes ah_cupones.mto_interes%TYPE;
      BEGIN
         SELECT SUM(nvl(mto_interes, 0))
           INTO v_mto_interes
           FROM ah_cupones
          WHERE nro_cuenta = p_nro_cuenta
            AND estado NOT IN ('V', 'P');

         RETURN nvl(v_mto_interes, 0);
      EXCEPTION
         WHEN no_data_found THEN
            RETURN 0;
         WHEN OTHERS THEN
            RETURN 0;
      END;

      FUNCTION lf_obt_int_devengar(p_nro_cuenta             ah_devengados.nro_cuenta%TYPE,
                                   p_fec_ult_capitalizacion ah_cta_certificados.fec_apertura%TYPE,
                                   p_est_certificado        ah_cta_certificados.estado%TYPE) RETURN NUMBER IS
         v_sal_int_devengar ah_devengados.mto_dev_acumulado%TYPE;
         v_tot_interes      ah_cupones.mto_interes%TYPE;
         v_int_devengado    ah_devengados.mto_dev_acumulado%TYPE;
      BEGIN
         SELECT SUM(a.mto_interes)
           INTO v_tot_interes
           FROM ah_cupones a
          WHERE a.estado IN ('E', 'C')
            AND p_est_certificado IN ('N', 'B')
            AND a.nro_cuenta = p_nro_cuenta;

         SELECT SUM(a.mto_dev_acumulado)
           INTO v_int_devengado
           FROM ah_devengados a
          WHERE nro_cuenta = p_nro_cuenta
            AND fec_inicio >= p_fec_ult_capitalizacion;

         v_sal_int_devengar := nvl(v_tot_interes, 0) - nvl(v_int_devengado, 0);

         --si el v_mto_dev_acumulado es negativo quiere decir que el CDA se cancelo
         --antes de su fecha, en ese caso devolver 0
         IF v_sal_int_devengar < 0 THEN
            v_sal_int_devengar := 0;
         END IF;

         RETURN nvl(v_sal_int_devengar, 0);
      EXCEPTION
         WHEN no_data_found THEN
            RETURN 0;
         WHEN OTHERS THEN
            RETURN 0;
      END;

      PROCEDURE lp_obt_dat_cta_corriente
      (
         p_nro_cuenta         IN  cc_cta_corrientes.nro_cuenta%TYPE,
         p_nro_ope_original   IN  sb_crc_operaciones_det.nro_operacion%TYPE,
         p_sal_capital        OUT sb_crc_saldos_det.sal_capital%TYPE,
         p_sal_tot_batch      OUT cc_cta_corrientes.sal_tot_batch%TYPE,
         p_sal_bloqueado      OUT cc_cta_corrientes.sal_blo_batch%TYPE,
         p_sal_ret_batch      OUT cc_cta_corrientes.sal_ret_batch%TYPE,
         p_cod_modalidad      OUT sb_crc_saldos_det.cod_modalidad%TYPE,
         p_cod_sec_contable   OUT ge_clientes.cod_sec_contable%TYPE,
         p_cod_tip_deudor     OUT ge_clientes.cod_tip_deudor%TYPE,
         p_residente          OUT ge_clientes.residente%TYPE,
         p_cod_moneda         OUT ge_cuentas.cod_moneda%TYPE,
         p_estado             OUT cc_cta_corrientes.estado%TYPE,
         -- Nuevo parámetro
         p_fec_ult_movimiento OUT cc_cta_corrientes.fec_ult_movimiento%TYPE
      ) IS
      BEGIN
         v_existe := lf_ver_exi_saldos(p_nro_ope_original, v_fec_inicio, v_fec_fin);
         SELECT nvl((nvl(sal_tot_batch, 0) - nvl(sal_blo_batch, 0) - nvl(sal_ret_batch, 0)), 0) sal_capital,
                nvl(sal_tot_batch,0) sal_tot_batch,
                nvl(sal_blo_batch,0) sal_blo_batch,
                nvl(sal_ret_batch,0) sal_ret_batch,
                a.cod_modalidad,
                c.cod_sec_contable,
                c.cod_tip_deudor,
                c.residente,
                d.cod_moneda,
                a.estado,
                a.fec_ult_movimiento                    -- Nuevo campo
           INTO p_sal_capital, p_sal_tot_batch, p_sal_bloqueado, p_sal_ret_batch, p_cod_modalidad, p_cod_sec_contable, p_cod_tip_deudor, p_residente, p_cod_moneda, p_estado,
                p_fec_ult_movimiento                    -- Nuevo parámetro
           FROM cc_cta_corrientes a, ge_cta_clientes b, ge_clientes c, ge_cuentas d
          WHERE b.cod_persona = c.cod_persona
            AND a.nro_cuenta = d.nro_cuenta
            AND a.nro_cuenta = p_nro_cuenta
            AND b.nro_cuenta = a.nro_cuenta
            AND b.relacion = 'P'
            AND (a.estado <> 'C' OR
                (a.estado = 'C' --Canceladas en el mes de informe.
                AND
                abs(nvl((nvl(sal_tot_batch, 0) - nvl(sal_blo_batch, 0) - nvl(sal_ret_batch, 0)), 0)) = 0 AND
                a.fec_cam_estado BETWEEN v_fec_inicio AND v_fec_fin AND v_existe = 'S'))
            AND NOT EXISTS (SELECT 1
                   FROM ge_par_dinamicos p
                  WHERE p.parametro = 'SIB_CRC_MAD_EXC_ARCHIVO'
                    AND p.cod_modalidad = a.cod_modalidad
                    AND nvl(p.val_parametro, 'N') = 'S')
           UNION
         SELECT nvl((nvl(sal_tot_batch, 0) - nvl(sal_blo_batch, 0) - nvl(sal_ret_batch, 0)), 0) sal_capital,
                sal_blo_batch,
                a.sal_tot_batch,
                a.sal_ret_batch,
                a.cod_modalidad,
                c.cod_sec_contable,
                c.cod_tip_deudor,
                c.residente,
                d.cod_moneda,
                a.estado,
                NULL                                    -- fec_ult_movimiento no aplica para cuentas bancarias
           FROM cc_cta_bancarias a, ge_cta_clientes b, ge_clientes c, ge_cuentas d
          WHERE b.cod_persona = c.cod_persona
            AND a.nro_cuenta = d.nro_cuenta
            AND a.nro_cuenta = p_nro_cuenta
            AND b.nro_cuenta = a.nro_cuenta
            AND b.relacion = 'P'
            AND (a.estado <> 'C' OR
                (a.estado = 'C' AND
                nvl((nvl(sal_tot_batch, 0) - nvl(sal_blo_batch, 0) - nvl(sal_ret_batch, 0)), 0) = 0 AND
                v_existe = 'S'))
            AND NOT EXISTS (SELECT 1
                   FROM ge_par_dinamicos p
                  WHERE p.parametro = 'SIB_CRC_MAD_EXC_ARCHIVO'
                    AND p.cod_modalidad = a.cod_modalidad
                    AND nvl(p.val_parametro, 'N') = 'S');

      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            NULL;
         WHEN OTHERS THEN
            p_sal_capital        := 0;
            p_fec_ult_movimiento := NULL;
      END;

      PROCEDURE lp_obt_dat_ope_cheque(p_nro_cuenta    IN sb_crc_operaciones_det.nro_operacion%TYPE,
                                      p_fec_operacion IN cc_cta_corrientes.fec_apertura%TYPE,
                                      p_sal_capital   OUT sb_crc_saldos_det.sal_capital%TYPE,
                                      p_cod_modalidad OUT sb_crc_saldos_det.cod_modalidad%TYPE,
                                      p_fec_vto_cuota OUT sb_crc_saldos_det.fec_vto_cuota%TYPE) IS
      BEGIN
         v_existe := lf_ver_exi_saldos(p_nro_cuenta, p_fec_operacion);
         SELECT a.monto, b.cod_modalidad, a.Fec_Final
           INTO p_sal_capital, p_cod_modalidad, p_fec_vto_cuota
           FROM cc_che_enviados a, ge_cta_clientes b, ge_clientes c, ge_cuentas d
          WHERE b.cod_persona = c.cod_persona
            AND a.nro_cuenta = d.nro_cuenta
            AND a.nro_cuenta = pae_uti.fu_obt_valor(p_nro_cuenta,1)
            AND a.nro_cheque = pae_uti.fu_obt_valor(p_nro_cuenta,2)
            AND b.nro_cuenta = a.nro_cuenta
            AND b.relacion = 'P'
            AND (a.estado = 'I' OR (a.estado <> 'I' AND a.monto = 0 AND a.fecha between v_fec_inicio and  v_fec_fin AND v_existe = 'S'))
            AND NOT EXISTS (SELECT 1
                   FROM ge_par_dinamicos p
                  WHERE p.parametro = 'SIB_CRC_MAD_EXC_ARCHIVO'
                    AND p.cod_modalidad = b.cod_modalidad
                    AND nvl(p.val_parametro, 'N') = 'S')
          UNION
        SELECT pr.monto, 71, pr.fec_final
          FROM cc_che_enviados pr, lc_che_comprados g
         WHERE pr.nro_cheque = g.nro_cheque(+)
           AND pr.cod_banco = g.cod_banco(+)
           AND pr.nro_cheque = pae_uti.fu_obt_valor(p_nro_cuenta,1)
           AND (pr.estado = 'I' OR (pr.estado <> 'I' AND pr.monto = 0 AND pr.fecha  between v_fec_inicio and  v_fec_fin AND v_existe = 'S'));
      EXCEPTION
         WHEN no_data_found THEN
            NULL;
         WHEN OTHERS THEN
            p_sal_capital   := 0;
            p_cod_modalidad := NULL;
            p_fec_vto_cuota := NULL;

      END;
      PROCEDURE lp_obt_dat_ope_vencida(p_nro_cuenta    IN ov_cta_vencidas.nro_cuenta%TYPE,
                                       p_fec_operacion      IN  ov_cta_vencidas.fec_apertura%TYPE,
                                       p_cod_modalidad      OUT ov_cta_vencidas.cod_modalidad%TYPE,
                                       p_dia_atraso         OUT ov_cta_vencidas.dia_atraso%TYPE,
                                       p_estado             OUT ov_cta_vencidas.estado%TYPE,
                                       -- NUEVO:
                                       p_fec_ult_movimiento OUT ov_cta_vencidas.fec_ult_movimiento%TYPE) IS
      BEGIN
         v_existe := lf_ver_exi_saldos(p_nro_cuenta, p_fec_operacion);
         SELECT cod_modalidad, nvl(dia_atraso, 0), estado,
                fec_ult_movimiento  -- NUEVO
           INTO p_cod_modalidad, p_dia_atraso, p_estado,
                p_fec_ult_movimiento  -- NUEVO
           FROM ov_cta_vencidas o
          WHERE nro_cuenta = p_nro_cuenta
            AND (estado <> 'C' OR (estado = 'C' AND sal_tot_batch = 0 AND v_existe = 'S'))
            AND NOT EXISTS (SELECT 1
                   FROM ge_par_dinamicos p
                  WHERE p.parametro = 'SIB_CRC_MAD_EXC_ARCHIVO'
                    AND p.cod_modalidad = o.cod_modalidad
                    AND nvl(p.val_parametro, 'N') = 'S');
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            NULL;
         WHEN OTHERS THEN
            p_dia_atraso         := 0;
            p_fec_ult_movimiento := NULL;  -- NUEVO
      END;
      PROCEDURE lp_obt_dat_mes_dinero(p_nro_cuenta             IN md_cta_documentos.nro_cuenta%TYPE,
                                      p_fec_operacion          IN md_cta_documentos.fec_inicio%TYPE,
                                      p_sal_capital            OUT md_cta_documentos.sal_capital%TYPE,
                                      p_val_int_devengar       OUT md_cta_documentos.val_int_devengar%TYPE,
                                      p_cod_modalidad          OUT md_cta_documentos.cod_modalidad%TYPE,
                                      p_dia_atraso             OUT sb_crc_saldos_det.dia_atraso%TYPE,
                                      p_dev_cobrado            OUT md_cta_documentos.sal_interes%TYPE,
                                      p_rub_con_dev_cobrado    OUT sb_crc_saldos_det.rub_con_int_devengar%TYPE,
                                      p_rub_con_dev_no_cobrado OUT sb_crc_saldos_det.rub_con_int_devengar%TYPE,
                                      p_estado                 OUT md_cta_documentos.estado%TYPE,
                                      p_sal_int_dev_no_cobrado OUT md_cta_documentos.sal_interes%TYPE) IS
         v_cod_sit_contable md_cta_documentos.cod_sit_contable%TYPE;
         v_cod_plazo        ge_plz_contables.cod_plazo%TYPE;
         v_tip_movimiento   ge_tip_asientos.tip_movimiento%TYPE;
         v_cod_tra_interes  ge_transacciones.cod_transaccion%TYPE;
         v_rub_dev_cobrado  sb_crc_saldos_det.rub_con_int_devengar%TYPE;
         v_cod_transaccion  ge_transacciones.cod_transaccion%TYPE;
      BEGIN
         --v_existe := lf_ver_exi_saldos(p_nro_cuenta, p_fec_operacion);
         SELECT CASE
                    WHEN est_batch <> 'N' THEN
                     nvl(sal_capital, 0)
                    ELSE
                     0
                 END sal_capital,
                CASE
                   WHEN estado <> 'N' THEN
                    nvl(val_int_devengar, 0)
                   ELSE
                    0
                END, cod_modalidad,
                CASE
                   WHEN (v_fec_fin - fec_vencimiento) > 0 THEN
                    (v_fec_fin - fec_vencimiento)
                   ELSE
                    0
                END,
                CASE WHEN estado <> 'N' THEN
                   nvl(dev_acumulado, 0)
                   else
                     0
                  END dev_cobrado,
                   estado,
                CASE WHEN estado <> 'N' THEN
                CASE
                    WHEN (nvl(m.sal_interes, 0) - nvl(m.val_int_devengar, 0)) < 0 THEN
                     0
                    ELSE
                     (nvl(m.sal_interes, 0) - nvl(m.val_int_devengar, 0))
                 END
                 ELSE
                   0
                 END dev_no_cobrado
           INTO p_sal_capital, p_val_int_devengar, p_cod_modalidad, p_dia_atraso, p_dev_cobrado, p_estado,
                p_sal_int_dev_no_cobrado
           FROM md_cta_documentos m
          WHERE nro_cuenta = p_nro_cuenta
            AND (estado <> 'N' /*OR
                (estado = 'N' --Canceladas en el mes de informe. FIELDESK 5171 VGONZALEZ 20/12/2021
                AND nvl(sal_capital, 0) = 0 AND
                (fec_cancelacion BETWEEN v_fec_inicio AND v_fec_fin OR fec_cancelacion IS NULL) AND v_existe = 'S')*/)
            AND NOT EXISTS (SELECT 1
                   FROM ge_par_dinamicos p
                  WHERE p.parametro = 'SIB_CRC_MAD_EXC_ARCHIVO'
                    AND p.cod_modalidad = m.cod_modalidad
                    AND nvl(p.val_parametro, 'N') = 'S');

         IF nvl(p_dev_cobrado, 0) > 0 THEN
            v_tip_movimiento  := 'D';
            v_cod_tra_interes := 719;
            IF p_cod_modalidad = 123 THEN
               v_tip_movimiento  := 'C';
               v_cod_tra_interes := 921;
            ELSIF p_cod_modalidad = 147 THEN
               v_tip_movimiento  := 'C';
               v_cod_tra_interes := 802;
            ELSIF p_cod_modalidad = 125 THEN
               v_tip_movimiento  := 'D';
               v_cod_tra_interes := 903;
            ELSIF p_cod_modalidad in (118) THEN
               v_tip_movimiento  := 'C';
               v_cod_tra_interes := 903;
            ELSIF (p_cod_modalidad IN (100, 101, 102, 105, 129, 132)) THEN
               --documentos originales en estado normal
               v_tip_movimiento := 'D';
               IF (v_cod_sit_contable = '10000001') THEN
                  v_cod_tra_interes := 813;
               ELSE
                  v_cod_tra_interes := 719;
               END IF;
            ELSIF (p_cod_modalidad IN (104, 124)) THEN
               --bonos privados
               v_tip_movimiento := 'D';
               IF (v_cod_sit_contable = '10000001') THEN
                  v_cod_tra_interes := 811;
               ELSE
                  v_cod_tra_interes := 719;
               END IF;
            ELSIF (p_cod_modalidad IN (106, 117)) THEN
               --bonos afd
               v_tip_movimiento  := 'D';
               v_cod_tra_interes := 719;
            END IF;
            v_rub_dev_cobrado := fu_obt_cod_rubro(p_nro_cuenta,null,null, v_cod_tra_interes, null,null,null,null,v_cod_plazo, v_tip_movimiento,null,p_estado,null,null,null,null,null);

            IF v_rub_dev_cobrado IS NULL THEN
               v_rub_dev_cobrado := fu_obt_cod_rubro(p_nro_cuenta,null,null, 901, null,null,null,null,null, v_tip_movimiento,null,null,null,null,null,null,null);
            END IF;
         END IF;
         p_rub_con_dev_no_cobrado := lf_obt_rub_padre(v_rub_dev_cobrado);

         ------rubro dev. cobrado
         IF nvl(p_dev_cobrado, 0) > 0 THEN
            IF p_cod_modalidad = 117 THEN
               v_tip_movimiento  := 'D';
               v_cod_transaccion := 901;
            ELSIF p_cod_modalidad IN (119, 112, 147, 124, 118) THEN
               v_tip_movimiento  := 'D';
               v_cod_transaccion := 901;
            ELSE
               v_tip_movimiento  := 'C';
               v_cod_transaccion := 901;
            END IF;
            p_rub_con_dev_cobrado := fu_obt_cod_rubro(p_nro_cuenta,null,null, v_cod_transaccion, null,null,null,null,null, v_tip_movimiento,null,null,null,null,null,null,null);
         END IF;
      EXCEPTION
         WHEN no_data_found THEN
            NULL;
         WHEN OTHERS THEN
            p_sal_capital      := 0;
            p_val_int_devengar := 0;
      END;

      FUNCTION lf_obt_can_cuo_cancelada(p_nro_cuenta md_doc_detalles.nro_cuenta%TYPE) RETURN NUMBER IS
         v_can_cuo_cancelada md_doc_detalles.nro_cuota%TYPE;
      BEGIN
         SELECT MAX(nro_cuota)
           INTO v_can_cuo_cancelada
           FROM md_doc_detalles
          WHERE nro_cuenta = p_nro_cuenta
          and estado='N';
         RETURN nvl(v_can_cuo_cancelada, 0);
      EXCEPTION
         WHEN OTHERS THEN
            RETURN 0;
      END;
     PROCEDURE lp_obt_dat_comex(p_nro_cuenta      IN cx_fianzas.nro_cuenta%TYPE,
                                 p_fec_operacion   IN cx_fianzas.fec_solicitud%TYPE,
                                 p_cod_modalidad   OUT cx_fianzas.cod_modalidad%TYPE,
                                 p_fec_vencimiento OUT cx_fianzas.fec_vencimiento%TYPE,
                                 p_estado          OUT cx_fianzas.estado%TYPE) IS
      BEGIN
        -- v_existe := lf_ver_exi_saldos(p_nro_cuenta, p_fec_operacion);
         SELECT a.cod_modalidad, a.fec_vencimiento, a.estado
           INTO p_cod_modalidad, p_fec_vencimiento, p_estado
           FROM cx_fianzas a, ge_cta_clientes b, ge_clientes c, ge_cuentas d
          WHERE a.nro_cuenta = b.nro_cuenta
            AND b.relacion = 'P'
            AND b.cod_persona = c.cod_persona
            AND a.nro_cuenta = d.nro_cuenta
            AND a.nro_cuenta = p_nro_cuenta
            AND (a.estado <> 'C' /*OR
                (a.estado = 'C' --Canceladas en el mes de informe. FIELDESK 5171 VGONZALEZ 20/12/2021
                AND (a.fec_cancelacion BETWEEN v_fec_inicio AND v_fec_fin OR fec_cancelacion IS NULL) AND
                v_existe = 'S')*/)
            AND NOT EXISTS (SELECT 1
                   FROM ge_par_dinamicos p
                  WHERE p.parametro = 'SIB_CRC_MAD_EXC_ARCHIVO'
                    AND p.cod_modalidad = a.cod_modalidad
                    AND nvl(p.val_parametro, 'N') = 'S')
         UNION ALL
         SELECT a.cod_modalidad, a.fec_vencimiento, a.estado
           FROM cx_cta_importaciones a, ge_cta_clientes b, ge_clientes c, ge_cuentas d,
                (SELECT MIN(fec_vencimiento) fec_vencimiento, MIN(nro_cuota) nro_cuota
                    FROM cx_cuotas
                   WHERE nro_cuenta = p_nro_cuenta
                     AND fec_vencimiento BETWEEN v_fec_inicio AND v_fec_fin) x
          WHERE a.nro_cuenta = b.nro_cuenta
            AND b.relacion = 'P'
            AND b.cod_persona = c.cod_persona
            AND a.nro_cuenta = d.nro_cuenta
            AND a.nro_cuenta = p_nro_cuenta
            AND (a.estado <> 'C' /*OR
                (a.estado = 'C' --Canceladas en el mes de informe. FIELDESK 5171 VGONZALEZ 20/12/2021
                AND (a.fec_cancelacion BETWEEN v_fec_inicio AND v_fec_fin OR fec_cancelacion IS NULL) AND
                v_existe = 'S')*/)
            AND NOT EXISTS (SELECT 1
                   FROM ge_par_dinamicos p
                  WHERE p.parametro = 'SIB_CRC_MAD_EXC_ARCHIVO'
                    AND p.cod_modalidad = a.cod_modalidad
                    AND nvl(p.val_parametro, 'N') = 'S')
         UNION ALL
         SELECT a.cod_modalidad, a.fec_vencimiento, a.estado
           FROM cx_cta_exportaciones a, ge_cta_clientes b, ge_clientes c, ge_cuentas d,
                (SELECT MIN(fec_vencimiento) fec_vencimiento, MIN(nro_cuota) nro_cuota
                    FROM cx_cuotas
                   WHERE nro_cuenta = p_nro_cuenta
                     AND fec_vencimiento BETWEEN v_fec_inicio AND v_fec_fin) x
          WHERE a.nro_cuenta = b.nro_cuenta
            AND b.relacion = 'P'
            AND b.cod_persona = c.cod_persona
            AND a.nro_cuenta = d.nro_cuenta
            AND a.nro_cuenta = p_nro_cuenta
            AND (a.estado <> 'C' /*OR
                (a.estado = 'C' --Canceladas en el mes de informe.FIELDESK 5171 VGONZALEZ 20/12/2021
                AND (a.fec_cancelacion BETWEEN v_fec_inicio AND v_fec_fin OR fec_cancelacion IS NULL) AND
                v_existe = 'S')*/)
            AND NOT EXISTS (SELECT 1
                   FROM ge_par_dinamicos p
                  WHERE p.parametro = 'SIB_CRC_MAD_EXC_ARCHIVO'
                    AND p.cod_modalidad = a.cod_modalidad
                    AND nvl(p.val_parametro, 'N') = 'S');
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            NULL;
         WHEN OTHERS THEN
            p_cod_modalidad   := NULL;
            p_fec_vencimiento := NULL;
      END;

      PROCEDURE lp_obt_dat_cta_pasivas(p_nro_cuenta             IN  cc_cta_corrientes.nro_cuenta%TYPE,
                                       p_fec_operacion          IN  cc_cta_corrientes.fec_apertura%TYPE,
                                       p_sal_capital            OUT sb_crc_saldos_det.sal_capital%TYPE,
                                       p_cod_modalidad          OUT sb_crc_saldos_det.cod_modalidad%TYPE,
                                       p_cod_transaccion        OUT ge_transacciones.cod_transaccion%TYPE,
                                       p_estado                 OUT ah_cta_certificados.estado%TYPE,
                                       p_fec_ult_capitalizacion OUT ah_cta_vistas.fec_ult_capitalizacion%TYPE,
                                       p_cod_moneda             OUT ba_monedas.cod_moneda%TYPE,
                                       -- Nuevo parámetro
                                       p_fec_ult_movimiento     OUT ah_cta_vistas.fec_ult_movimiento%TYPE) IS
      BEGIN
        -- v_existe := lf_ver_exi_saldos(p_nro_cuenta, p_fec_operacion);

          SELECT CASE WHEN nvl(sal_tot_batch, 0) <0 THEN 0
                      WHEN nvl(sal_total, 0) <> nvl(sal_tot_batch, 0) THEN nvl(sal_tot_batch, 0)
                      WHEN nvl(sal_total, 0)=0 THEN nvl(sal_tot_batch, 0) - nvl(sal_ret_batch, 0)


                ELSE nvl(sal_total, 0) - nvl(sal_retenido, 0) END sal_capital, a.cod_modalidad,
                decode(nvl(a.cta_combinada, 'N'), 'S', 682, 602) cod_tra_capital, a.estado, a.fec_ult_capitalizacion,
                a.cod_moneda,
                a.fec_ult_movimiento                    -- Nuevo campo
           INTO p_sal_capital, p_cod_modalidad, p_cod_transaccion, p_estado, p_fec_ult_capitalizacion, p_cod_moneda,
                p_fec_ult_movimiento                    -- Nuevo parámetro
           FROM ah_cta_vistas a, ge_cta_clientes b, ge_clientes c, ge_cuentas d
          WHERE b.cod_persona = c.cod_persona
            AND a.nro_cuenta = d.nro_cuenta
            AND a.nro_cuenta = p_nro_cuenta
            AND b.nro_cuenta = a.nro_cuenta
            AND b.relacion = 'P'
            AND (a.estado <> 'C' /*OR
                (a.estado = 'C' --Canceladas en el mes de informe. FIELDESK 5171 VGONZALEZ 20/12/2021
                AND abs(nvl((nvl(sal_tot_batch, 0) - nvl(sal_blo_batch, 0) - nvl(sal_ret_batch, 0)), 0)) = 0 AND
                a.fec_cam_estado BETWEEN v_fec_inicio AND v_fec_fin AND v_existe = 'S')*/)
            AND NOT EXISTS (SELECT 1
                   FROM ge_par_dinamicos p
                  WHERE p.parametro = 'SIB_CRC_MAD_EXC_ARCHIVO'
                    AND p.cod_modalidad = a.cod_modalidad
                    AND nvl(p.val_parametro, 'N') = 'S')
         UNION
         SELECT nvl(sal_total, 0) - nvl(sal_retenido, 0) sal_capital, a.cod_modalidad,
                decode(decode(a.est_batch,'P', 'V', a.estado), 'V', 604, 602) cod_tra_capital,
                decode(a.est_batch,
                        'B',
                        decode(a.est_cer_batch, 'V', 'V', 'N'),
                        decode(a.est_batch, 'P', 'V', a.est_batch)) estado,
                nvl(a.fec_ult_capitalizacion, a.fec_apertura), a.cod_moneda,
                NULL                                    -- fec_ult_movimiento no aplica para certificados
           FROM ah_cta_certificados a, ge_cta_clientes b, ge_clientes c, ge_cuentas d
          WHERE b.cod_persona = c.cod_persona
            AND a.nro_cuenta = d.nro_cuenta
            AND a.nro_cuenta = p_nro_cuenta
            AND b.nro_cuenta = a.nro_cuenta
            AND b.relacion = 'P'
            AND (a.estado NOT IN ('C', 'T') /*OR
                (a.estado IN ('C', 'T') --Canceladas o totalmente pagadas en el mes de informe.FIELDESK 5171 VGONZALEZ 20/12/2021
                AND abs(nvl((nvl(sal_tot_batch, 0) - nvl(sal_blo_batch, 0) - nvl(sal_ret_batch, 0)), 0)) = 0 AND
                a.fec_cam_estado BETWEEN v_fec_inicio AND v_fec_fin AND v_existe = 'S')*/)
            AND NOT EXISTS (SELECT 1
                   FROM ge_par_dinamicos p
                  WHERE p.parametro = 'SIB_CRC_MAD_EXC_ARCHIVO'
                    AND p.cod_modalidad = a.cod_modalidad
                    AND nvl(p.val_parametro, 'N') = 'S')
     UNION
           SELECT nvl(sal_total, 0) - nvl(sal_retenido, 0) sal_capital, a.cod_modalidad,
               null /*decode(nvl(a.cta_combinada, 'N'), 'S', 682, 602) cod_tra_capital*/, a.estado, a.fec_ult_capitalizacion,
                a.cod_moneda,
                NULL                                    -- fec_ult_movimiento no aplica para plazos

           FROM ah_cta_plazos a, ge_cta_clientes b, ge_clientes c, ge_cuentas d
          WHERE b.cod_persona = c.cod_persona
            AND a.nro_cuenta = d.nro_cuenta
            AND a.nro_cuenta = p_nro_cuenta
            AND b.nro_cuenta = a.nro_cuenta
            AND b.relacion = 'P'
            AND a.estado not in ('C','T')
            AND NOT EXISTS (SELECT 1
                   FROM ge_par_dinamicos p
                  WHERE p.parametro = 'SIB_CRC_MAD_EXC_ARCHIVO'
                    AND p.cod_modalidad = a.cod_modalidad);
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            NULL;
         WHEN OTHERS THEN
            p_sal_capital := 0;
      END;
      PROCEDURE lp_obt_mto_prevision
      (
         p_mto_prevision    IN ge_cla_operaciones.tot_prevision%TYPE,
         p_mto_con_acuerdo  IN NUMBER,
         p_mto_sin_acuerdo  IN NUMBER,
         p_pre_con_acuerdo OUT NUMBER,
         p_pre_sin_acuerdo OUT NUMBER
      ) IS
        v_tot_monto        NUMBER(22,2);
        v_por_con_acuerdo  NUMBER(5,2);
        v_por_sin_acuerdo  NUMBER(5,2);
      BEGIN
        IF p_mto_con_acuerdo > 0 AND p_mto_sin_acuerdo > 0 THEN
           v_tot_monto := p_mto_con_acuerdo + p_mto_sin_acuerdo;
           v_por_con_acuerdo := ROUND(((p_mto_con_acuerdo * 100)/v_tot_monto), 2);
           v_por_sin_acuerdo := ROUND(((p_mto_sin_acuerdo * 100)/v_tot_monto), 2);
           p_pre_con_acuerdo := ROUND((p_mto_prevision * (v_por_con_acuerdo/100)));
           p_pre_sin_acuerdo := ROUND((p_mto_prevision * (v_por_sin_acuerdo/100)));
        ELSIF p_mto_con_acuerdo > 0 THEN
           p_pre_con_acuerdo := p_mto_prevision;
           p_pre_sin_acuerdo := 0;
        ELSE
           p_pre_con_acuerdo := 0;
           p_pre_sin_acuerdo := p_mto_prevision;
        END IF;
      END;
      FUNCTION lf_obt_int_dev_ahorros(p_nro_cuenta    ah_cupones.nro_cuenta%TYPE,
                                      p_cod_modalidad IN ge_cuentas.cod_modalidad%TYPE) RETURN NUMBER IS
         v_mto_interes ah_cupones.mto_interes%TYPE;
      BEGIN
         IF p_cod_modalidad in (33, 34) THEN
            SELECT SUM(nvl(mto_interes, 0))
              INTO v_mto_interes
              FROM ah_cupones
             WHERE nro_cuenta = p_nro_cuenta
               AND estado NOT IN ('V', 'P')
               AND fec_vencimiento >= v_fec_fin;
         END IF;
         RETURN nvl(v_mto_interes, 0);
      EXCEPTION
         WHEN OTHERS THEN
            RETURN 0;
      END;


    PROCEDURE lp_obt_tip_saldo (p_nro_cuenta     IN ge_cla_operaciones.nro_cuenta%TYPE,
                               p_tip_saldo      IN cb_sal_inventarios.tip_saldo%TYPE,
                               p_tip_operacion  IN SB_CRC_SALDOS_DET.tip_operacion%type  DEFAULT NULL,
                               p_rubro          IN OUT SB_CRC_SALDOS_DET.RUB_CON_CAPITAL%TYPE,
                               p_sal_actual     IN OUT SB_CRC_SALDOS_DET.sal_capital%TYPE
                               ) IS
     BEGIN


    select  case when p_tip_saldo = 'C' THEN a.cod_rubro
             WHEN p_tip_saldo != 'C' THEN  DECODE(SAL_ACTUAL,0,NULL,a.cod_rubro)
             END CASE
     ,SAL_ACTUAL
     into p_rubro, p_sal_actual
     FROM cb_sal_inventarios a, cb_sal_inventarios_det d
     WHERE a.nro_referencia = d.nro_referencia
     AND d.nro_cuenta = p_nro_cuenta
     AND a.tip_saldo = p_tip_saldo
     AND substr(a.cod_rubro, 6, 3) = nvl(p_tip_operacion,substr(a.cod_rubro, 6, 3))
     AND (p_tip_saldo = 'O' AND substr(a.cod_rubro, 1, 2)= 41 OR p_tip_saldo != 'O')
     order by SAL_TOTAL desc
     FETCH FIRST ROW ONLY
     ;

   EXCEPTION
      WHEN OTHERS THEN
          begin
              select  case when p_tip_saldo = 'C' THEN a.cod_rubro
                     WHEN p_tip_saldo != 'C' THEN  DECODE(SAL_ACTUAL,0,NULL,a.cod_rubro)
                     END CASE
             ,SAL_ACTUAL
             into p_rubro, p_sal_actual
             FROM cb_sal_inventarios a, cb_sal_inventarios_det d
             WHERE a.nro_referencia = d.nro_referencia
             AND d.nro_cuenta = p_nro_cuenta
             AND a.tip_saldo = p_tip_saldo
             and instr(v_tip_op_sob_gir_cta_corriente,substr(a.cod_rubro, 6, 3))>0
             AND (p_tip_saldo = 'O' AND substr(a.cod_rubro, 1, 2)= 41 OR p_tip_saldo != 'O')
             order by SAL_TOTAL desc
             FETCH FIRST ROW ONLY
             ;
          EXCEPTION
          WHEN OTHERS THEN
          p_rubro:=null;
          p_sal_actual:=0;
          END;
   END;

   BEGIN
      --- Iniciar registro
      pag_cal.pr_obt_dat_calendar(1);
      v_fec_actual  := pag_cal.fu_obt_fec_actual(1);
      IF v_fec_actual = pag_cal.G_ULT_DIA_MES_HABIL THEN
         lp_crc_gen_dat_saldos('M');
         v_periodo := 'M';
      ELSE
         lp_crc_gen_dat_saldos('D');
         v_periodo := 'D';
      END IF;
      rp_gcsal.nom_referencia := 'SALDOS';
      rp_gcsal.nro_formulario := '003';
      --- Inicializar variables a utilizar
      v_tip_cierre          := NULL;
      v_fec_apertura        := NULL;
      v_dev_no_cobrado      := 0;
      v_tot_prevision       := 0;
      v_tot_deu_contingente := 0;
      v_tot_gar_computables := 0;
      v_cat_automatica      := NULL;
      v_fec_vencimiento     := NULL;
      v_nro_cuenta          := NULL;
      v_nro_cuota           := NULL;
      v_nro_cheque          := NULL;

     FOR m IN (SELECT column_value FROM table(sys.dbms_debug_vc2coll(10,15,4,5,3,6,8))) LOOP
      dbms_output.put_line( 'Modulo: ' || m.column_value ||' Periodo: ' || v_periodo    );
      PRG_INS_LOG_PROGRAMAS('PAS_CRI.SALDOS',systimestamp ||' Inicio Modulo: '|| m.column_value, null, null);

      OPEN c_saldos(v_periodo,m.column_value);
      loop
        FETCH c_saldos into i;
        exit when c_saldos%notFOUND;
        begin
         v_exi_ope_ccc_sobregiro:=0;
         v_sal_bloqueado := 0;
         --Ceramos todas las variables para no arrastrar saldos que no correspoden
         v_mensaje                        := NULL;
         rp_gcsal.tip_operacion           := NULL;
         rp_gcsal.nro_operacion           := NULL;
         rp_gcsal.cod_modulo              := NULL;
         rp_gcsal.cod_modalidad           := NULL;
         rp_gcsal.fec_corte               := NULL;
         rp_gcsal.fec_vto_cuota           := NULL;
         rp_gcsal.fec_vto_cuo_vencida     := NULL;
         rp_gcsal.dia_atraso              := 0;
         rp_gcsal.rub_con_capital         := NULL;
         rp_gcsal.sal_capital             := 0;
         rp_gcsal.sal_cuo_vencida         := 0;
         rp_gcsal.con_mon_iso             := NULL;
         rp_gcsal.rub_con_int_devengar    := NULL;
         rp_gcsal.sal_int_devengar        := 0;
         rp_gcsal.rub_con_dev_no_cobrado  := NULL;
         rp_gcsal.sal_int_dev_no_cobrado  := 0;
         rp_gcsal.rub_con_int_dev_cobrado := NULL;
         rp_gcsal.sal_int_dev_cobrado     := 0;
         rp_gcsal.rub_con_dev_suspenso    := NULL;
         rp_gcsal.sal_int_suspenso        := 0;
         rp_gcsal.rub_con_contingencia    := NULL;
         rp_gcsal.mto_contingencia        := 0;
         rp_gcsal.tas_efectiva            := 0;
         rp_gcsal.rub_con_prevision       := NULL;
         rp_gcsal.mto_prevision           := 0;
         rp_gcsal.can_cuo_pagadas         := 0;
         rp_gcsal.cla_riesgo              := 1;
         v_estado                         := NULL;
         v_int_cda_vencido                := 0;
         v_tot_prevision                  := 0;
         v_nro_cuenta                     := null;
         v_nro_cuota                      := NULL;
         v_sal_capital                    := NULL;
         v_cod_ofi_procesada              := i.cod_oficina;
         v_tip_ope_procesada              := i.tip_operacion;
         v_nro_ope_procesada              := i.nro_ope_original;
         v_con_mon_iso                    := i.cod_moneda;
         v_can_cuo_rrr                    := 1;
         rp_gcsal.fecha           := v_fec_fin;
         rp_gcsal.fec_corte       := v_fec_fin;
         rp_gcsal.cod_modulo      := i.cod_modulo;
         rp_gcsal.cod_oficina     := i.cod_oficina;
         rp_gcsal.con_mon_iso     := i.cod_moneda;
         rp_gcsal.nro_operacion   := i.nro_ope_original;
         rp_gcsal.tip_operacion   := i.tip_operacion;
         rp_gcsal.rub_con_capital := pab_asi.fu_obt_rub_contable(i.nro_ope_original, 'C');


       IF rp_gcsal.tip_operacion = 205 and substr(rp_gcsal.rub_con_capital, 6, 3) = '260'  --NOR-21
         THEN
            rp_gcsal.rub_con_capital := fug_obt_pardinamico('TIP_OPE_CTA_TARJETA');
         END IF;

   if rp_gcsal.rub_con_capital is null then
    rp_gcsal.rub_con_capital := pab_asi.fu_obt_rub_contable(i.nro_ope_original, 'F'); --Prestamos AFD

          if  rp_gcsal.rub_con_capital is null then
              rp_gcsal.rub_con_capital := pab_asi.fu_obt_rub_contable(i.nro_cuenta, 'C');
          end if; --Para Tarjetas

         end if;

         if v_nro_registro is null then
            select NVL(max(nro_registro),1) into v_nro_registro from  sb_crc_saldos_det
            WHERE fecha BETWEEN v_fec_fin AND v_fec_fin
            AND nom_referencia = 'SALDOS';
         end if;

         --- Desparseo del Nro. de Operacion en Cuenta-Nro. Cuota-Cheque/Documento
         -- Para saldos bloqueados
         IF i.cod_modulo IN (3, 4) THEN
            v_sal_bloqueado := nvl(lf_obt_sal_bloqueado(i.nro_operacion), 0);
         END IF;
         if i.cod_modulo = 6 then
           BEGIN
              v_nro_cuenta := pae_uti.fu_obt_valor(i.nro_ope_original, 1);
              v_nro_cuota  := pae_uti.fu_obt_valor(i.nro_ope_original, 2);
              v_nro_cheque := pae_uti.fu_obt_valor(i.nro_ope_original, 3);-- no es cheque en otra entidad.
           EXCEPTION
              WHEN OTHERS THEN
                 v_nro_cuota  := null;
                 v_nro_cheque := null;
           END;
         end if;
         ---
         lp_obt_dat_cla_operaciones(i.nro_cuenta ,
                                    v_dev_no_cobrado,
                                    v_tot_prevision,
                                    v_tot_deu_contingente,
                                    v_tot_gar_computables,
                                    v_cat_automatica);
         IF v_nro_cuenta <> 0 THEN
            lp_obt_dat_cla_operaciones(v_nro_cuenta,
                                       v_dev_no_cobrado,
                                       v_tot_prevision,
                                       v_tot_deu_contingente,
                                       v_tot_gar_computables,
                                       v_cat_automatica);
         END IF;
         IF v_dev_no_cobrado < 0 THEN
            v_dev_no_cobrado := 0;
         END IF;

         IF i.tip_operacion <> '183' or i.cod_modalidad = '660'  THEN
            --- Sacar de las validaciones a cheques comprados, ya que puede ser de cualquier modalidad
            IF i.cod_modulo = 6 THEN
               IF i.tip_renovacion = 'N' AND v_cod_entidad = 6004 THEN
                  -- RENOVACION
                  v_nro_cta_anterior := i.nro_ope_original;
                  LOOP
                     BEGIN
                        SELECT nro_cuenta, tip_renovacion
                          INTO v_nro_cta_renovada, v_tip_renovacion
                          FROM pr_cta_prestamos
                         WHERE nro_cta_renovada = v_nro_cta_anterior;
                     EXCEPTION
                        WHEN NO_DATA_FOUND THEN
                           v_nro_cta_renovada := NULL;
                           v_tip_renovacion   := NULL;
                        WHEN OTHERS THEN
                           v_nro_cta_renovada := NULL;
                           v_tip_renovacion   := NULL;
                     END;
                     BEGIN
                        SELECT nro_operacion
                          INTO v_nro_cta_anterior
                          FROM sb_crc_operaciones_det
                         WHERE nro_operacion = v_nro_cta_renovada;
                     EXCEPTION
                        WHEN NO_DATA_FOUND THEN
                           v_nro_cta_anterior := NULL;
                        WHEN OTHERS THEN
                           v_nro_cta_anterior := NULL;
                     END;
                     EXIT WHEN v_nro_cta_renovada IS NULL OR v_tip_renovacion <> 'N' OR v_nro_cta_anterior IS NULL;
                     v_nro_cta_anterior := v_nro_cta_renovada;
                  END LOOP;
                  BEGIN
                     SELECT d.cod_oficina, d.tip_operacion, d.nro_operacion, d.cod_moneda
                       INTO rp_gcsal.cod_oficina, rp_gcsal.tip_operacion, rp_gcsal.nro_operacion, rp_gcsal.con_mon_iso
                       FROM sb_crc_operaciones_det d
                      WHERE d.nro_operacion = v_nro_cta_renovada;
                  EXCEPTION
                     WHEN OTHERS THEN
                        NULL;
                  END;
               END IF;
               IF i.nro_ope_original LIKE ('%##%') and i.nro_cuenta is not null THEN
                  rp_gcsal.rub_con_capital := pab_asi.fu_obt_rub_contable(i.nro_cuenta, 'C');
                  v_can_cuo_rrr := lf_can_cuo_rrr(i.nro_cuenta);
                  lp_obt_dat_cla_operaciones(i.nro_cuenta,
                                       v_dev_no_cobrado,
                                       v_tot_prevision,
                                       v_tot_deu_contingente,
                                       v_tot_gar_computables,
                                       v_cat_automatica);
                   -- CTAS. RENOVADAS
                  lp_obt_dat_cuentas(v_fec_fin,
                                  i.nro_cuenta,
                                  i.cod_modulo,
                                  rp_gcsal.fec_vto_cuota,
                                  rp_gcsal.fec_vto_cuo_vencida,
                                  rp_gcsal.sal_cuo_vencida);

                  lp_obt_dat_prestamo(i.nro_cuenta,
                                     i.fecha,
                                     v_est_batch,
                                     v_estado,
                                     v_sal_capital,
                                     rp_gcsal.sal_int_devengar,
                                     rp_gcsal.sal_int_dev_cobrado,
                                     rp_gcsal.sal_int_suspenso,
                                     rp_gcsal.can_cuo_pagadas,
                                     rp_gcsal.dia_atraso,
                                     rp_gcsal.cod_modalidad,
                                     rp_gcsal.rub_con_int_dev_cobrado,
                                     v_tip_operacion,
                                     rp_gcsal.rub_con_dev_no_cobrado,
                                     rp_gcsal.sal_int_dev_no_cobrado);
                       begin
                       rp_gcsal.sal_capital := v_sal_capital/ v_can_cuo_rrr;
                       rp_gcsal.sal_int_devengar :=  rp_gcsal.sal_int_devengar / v_can_cuo_rrr;
                       rp_gcsal.sal_int_dev_cobrado :=  rp_gcsal.sal_int_dev_cobrado/ v_can_cuo_rrr;
                       rp_gcsal.sal_int_suspenso := rp_gcsal.sal_int_suspenso / v_can_cuo_rrr;
                       rp_gcsal.sal_int_dev_no_cobrado :=  rp_gcsal.sal_int_dev_no_cobrado / v_can_cuo_rrr;
                       v_tot_prevision := v_tot_prevision  / v_can_cuo_rrr;
                       v_dev_no_cobrado := v_dev_no_cobrado  / v_can_cuo_rrr;
                       exception
                         when others then-- Se agrega el comentario para saber que operacion dio error por divisor igual a cero --FIELDESK-34615
                           raise_application_error(-20000,'error cuenta: '|| i.nro_cuenta||'-'||sqlerrm);
                       end;

               ELSE
                 lp_obt_dat_cuentas(v_fec_fin,
                                    i.nro_ope_original,
                                    i.cod_modulo,
                                    rp_gcsal.fec_vto_cuota,
                                    rp_gcsal.fec_vto_cuo_vencida,
                                    rp_gcsal.sal_cuo_vencida);

                 lp_obt_dat_prestamo(i.nro_ope_original,
                                     i.fecha,
                                     v_est_batch,
                                     v_estado,
                                     rp_gcsal.sal_capital,
                                     rp_gcsal.sal_int_devengar,
                                     rp_gcsal.sal_int_dev_cobrado,
                                     rp_gcsal.sal_int_suspenso,
                                     rp_gcsal.can_cuo_pagadas,
                                     rp_gcsal.dia_atraso,
                                     rp_gcsal.cod_modalidad,
                                     rp_gcsal.rub_con_int_dev_cobrado,
                                     v_tip_operacion,
                                     rp_gcsal.rub_con_dev_no_cobrado,
                                     rp_gcsal.sal_int_dev_no_cobrado);
                END IF;
               IF v_nro_cuenta <> 0 and v_nro_cuota IS NOT NULL THEN
                  lp_obt_dat_cta_cheque(v_fec_fin,
                                        v_nro_cuenta /*cuenta*/,
                                        v_nro_cuota /*cuota*/,
                                        v_nro_cheque /*cheque*/,
                                        rp_gcsal.fec_vto_cuota,
                                        rp_gcsal.fec_vto_cuo_vencida,
                                        v_sal_cuo_vencida,
                                        v_can_cuo_vencidas);

                  lp_obt_dat_cheque(v_nro_cuenta /*cuenta*/,
                                    /*nro operacion*/
                                    i.nro_ope_original,
                                    v_nro_cuota /*cuota*/,
                                    v_nro_cheque /*cheque*/,
                                    i.cod_persona,
                                    i.fecha,
                                    v_est_batch,
                                    v_estado,
                                    rp_gcsal.sal_capital,
                                    rp_gcsal.sal_int_devengar,
                                    rp_gcsal.sal_int_dev_cobrado,
                                    rp_gcsal.sal_int_suspenso,
                                    rp_gcsal.can_cuo_pagadas,
                                    v_dia_atraso,
                                    rp_gcsal.cod_modalidad,
                                    rp_gcsal.rub_con_int_dev_cobrado,
                                    v_tip_operacion,
                                    rp_gcsal.rub_con_dev_no_cobrado,
                                    rp_gcsal.sal_int_dev_no_cobrado,
                                    rp_gcsal.rub_con_capital,
                                    rp_gcsal.rub_con_int_devengar,
                                    rp_gcsal.rub_con_dev_suspenso,
                                    rp_gcsal.tas_efectiva,
                                    v_can_cuotas);
                 IF lf_es_cuo_vencida(v_nro_cuenta, v_nro_cuota) = 'S' THEN
                    rp_gcsal.dia_atraso := v_dia_atraso;
                    rp_gcsal.sal_cuo_vencida := v_sal_cuo_vencida;
                 ELSE
                    rp_gcsal.dia_atraso := 0;
                    rp_gcsal.sal_cuo_vencida := 0;
                 END IF;

                  --- si no es cheque busca en documento
                  IF rp_gcsal.cod_modalidad is null THEN
                     lp_obt_dat_documento(v_nro_cuenta /*nro cuenta*/,
                                          i.nro_ope_original, /*operacion*/
                                          v_nro_cuota /*cuota*/,
                                          v_nro_cheque /*cheque*/,
                                          i.cod_persona,
                                          i.fecha,
                                          v_est_batch,
                                          v_estado,
                                          rp_gcsal.sal_capital,
                                          rp_gcsal.sal_int_devengar,
                                          rp_gcsal.sal_int_dev_cobrado,
                                          rp_gcsal.sal_int_suspenso,
                                          rp_gcsal.can_cuo_pagadas,
                                          rp_gcsal.dia_atraso,
                                          rp_gcsal.cod_modalidad,
                                          rp_gcsal.rub_con_int_dev_cobrado,
                                          v_tip_operacion,
                                          rp_gcsal.rub_con_dev_no_cobrado,
                                          rp_gcsal.sal_int_dev_no_cobrado,
                                          rp_gcsal.rub_con_capital,
                                          rp_gcsal.rub_con_int_devengar,
                                          rp_gcsal.rub_con_dev_suspenso,
                                          rp_gcsal.tas_efectiva,
                                          v_can_cuotas);
                     IF lf_es_cuo_vencida(v_nro_cuenta, v_nro_cuota) = 'S' THEN
                        rp_gcsal.dia_atraso := v_dia_atraso;
                        rp_gcsal.sal_cuo_vencida := v_sal_cuo_vencida;
                     ELSE
                        rp_gcsal.dia_atraso := 0;
                        rp_gcsal.sal_cuo_vencida := 0;
                     END IF;
                  END IF;


                     --Prorrateo de prevision
                     IF nvl(FUG_OBT_PARDINAMICO('TIP_DES_DOCUMENTOS', 6, rp_gcsal.cod_modalidad, null, null), 'X') in
                        ('C', 'D') then
                        lp_obt_dat_libradores(v_nro_cuenta, i.cod_persona, v_nro_cuo_vigente, v_sal_cuo_vigente, v_can_cuotas);
                        IF nvl(v_tot_prevision, 0) <> 0 THEN
                           --v_tot_prevision := round(nvl(v_tot_prevision, 0) / v_can_cuo_vencidas, v_redondeo);
                            v_tot_prevision := round(nvl(v_tot_prevision, 0)* (rp_gcsal.sal_capital/ v_sal_cuo_vigente), v_redondeo);
                        END IF;
                   /*     IF nvl(FUG_OBT_PARDINAMICO('TIP_DES_DOCUMENTOS', 6, rp_gcsal.cod_modalidad, null, null), 'X') = 'D' THEN
                          IF nvl(v_dev_no_cobrado, 0) <> 0 AND rp_gcsal.sal_capital > 0 THEN
                             v_dev_no_cobrado:= round(nvl(v_dev_no_cobrado, 0) / v_can_cuotas, v_redondeo);
                          END IF;
                        ELSE*/
                          v_dev_no_cobrado := rp_gcsal.sal_int_dev_no_cobrado;
                       -- END IF;

                     ELSE
                        IF i.nro_ope_original NOt LIKE ('%##%') then
                           lp_obt_dat_mto_cuo_pre(v_nro_cuenta /*cuenta*/,
                                               v_nro_cuota /*cuota*/,
                                               v_can_cuotas,
                                               v_tot_prevision);
                         END IF;
                     END IF;
                  IF nvl(v_tot_prevision, 0) <> 0 THEN
                     IF v_tot_prevision > 0 THEN
                        rp_gcsal.rub_con_prevision := pab_asi.fu_obt_rub_contable(v_nro_cuenta, 'V');
                        IF rp_gcsal.rub_con_prevision IS NULL THEN

                           rp_gcsal.rub_con_prevision := IT.pas_cri.fu_obt_cod_rubro(v_nro_cuenta,null,null, 730, null,null,null,null,1, 'C',null,v_estado,null,null,null,null,null);

                        END IF;
                     END IF;
                  END IF;
               END IF;
               IF rp_gcsal.dia_atraso = 0 THEN
                  rp_gcsal.fec_vto_cuo_vencida := rp_gcsal.fec_vto_cuota;
               END IF;

               -- Para comparar los informes de BCP se decidio en el caso de incobrables sumar los intereses al capital.
               IF v_estado = 'I' THEN
                  rp_gcsal.cla_riesgo              := 6;
                  rp_gcsal.sal_capital             := rp_gcsal.sal_capital + rp_gcsal.sal_int_dev_no_cobrado;
                  rp_gcsal.sal_int_dev_no_cobrado  := 0;
                  rp_gcsal.sal_int_dev_cobrado     := 0;
                  rp_gcsal.sal_int_devengar        := 0;
                  rp_gcsal.rub_con_int_dev_cobrado := NULL;
                  rp_gcsal.rub_con_dev_no_cobrado  := NULL;
                  rp_gcsal.rub_con_int_devengar    := NULL;
               END IF;
               IF rp_gcsal.sal_capital = 0 THEN
                  rp_gcsal.dia_atraso := 0;
                  rp_gcsal.sal_cuo_vencida := 0;
               END IF;
               IF v_estado IN ('C', 'A') THEN
                  IF v_tip_operacion = 'A' THEN
                     v_cod_transaccion := 801;
                  ELSE
                     v_cod_transaccion := 805;
                  END IF;
               ELSIF v_estado = 'V' THEN
                  IF v_tip_operacion = 'A' THEN
                     v_cod_transaccion := 820;
                  ELSE
                     v_cod_transaccion := 821;
                  END IF;
               ELSIF v_estado = 'G' THEN
                  v_cod_transaccion := 822;
               ELSIF v_estado IN ('M', 'I') THEN
                  v_cod_transaccion := 823;
               END IF;
               IF rp_gcsal.rub_con_capital IS NULL THEN
                  IF v_estado = 'N' THEN
                     rp_gcsal.rub_con_capital := i.cta_con_cap_original;
                  ELSE
                     rp_gcsal.rub_con_capital := IT.pas_cri.fu_obt_cod_rubro(i.nro_cuenta,null,null, v_cod_transaccion, null,null,null,null,1, 'C',null,v_estado,null,null,null,null,null);

                  END IF;
               END IF;
               IF v_estado = 'N' THEN
                  rp_gcsal.tas_efectiva            := NULL;
                  rp_gcsal.can_cuo_pagadas         := 0;
                  rp_gcsal.sal_int_dev_cobrado     := 0;
                  rp_gcsal.fec_vto_cuo_vencida     := NULL;
                  rp_gcsal.fec_vto_cuota           := NULL;
                  rp_gcsal.rub_con_int_dev_cobrado := NULL;
                  rp_gcsal.rub_con_dev_no_cobrado  := NULL;
                  rp_gcsal.rub_con_int_devengar    := NULL;
                  rp_gcsal.sal_int_devengar        := 0;
                  rp_gcsal.sal_int_dev_cobrado     := 0;
                  rp_gcsal.sal_int_dev_no_cobrado  := 0;
               END IF;
               IF rp_gcsal.cod_modalidad = 660 THEN
                  IF rp_gcsal.fec_vto_cuota IS NULL THEN
                     rp_gcsal.fec_vto_cuota := i.fec_pri_vencimiento;
                  END IF;
                  IF i.fecha = rp_gcsal.fec_vto_cuo_vencida THEN
                     rp_gcsal.fec_vto_cuo_vencida := rp_gcsal.fec_vto_cuo_vencida + 1;
                  END IF;
               END IF;
               if rp_gcsal.rub_con_int_devengar is null then
                  rp_gcsal.rub_con_int_devengar := pab_asi.fu_obt_rub_contable(i.nro_cuenta, 'A');
               end if;
               IF rp_gcsal.rub_con_int_devengar IS NULL AND rp_gcsal.sal_int_devengar > 0 THEN
                  v_tip_movimiento := 'C';
                  IF v_estado IN ('C', 'A') THEN
                     v_cod_transaccion := 905;
                     v_tip_movimiento  := 'D';
                  ELSIF v_estado = 'V' THEN
                     v_cod_transaccion := 906;
                  ELSIF v_estado = 'G' THEN
                     v_cod_transaccion := 909;
                  ELSIF v_estado IN ('M', 'I') THEN
                     v_cod_transaccion := 910;
                  END IF;
                  rp_gcsal.rub_con_int_devengar := IT.pas_cri.fu_obt_cod_rubro(i.nro_cuenta,null,null, v_cod_transaccion, null,null,null,null,null,v_tip_movimiento,null,null,null,null,null,null,null);

               END IF;
               IF rp_gcsal.rub_con_dev_suspenso IS NULL THEN
                  rp_gcsal.rub_con_dev_suspenso := pab_asi.fu_obt_rub_contable(i.nro_cuenta, 'S');
               END IF;
               rp_gcsal.rub_con_contingencia := NULL;
               rp_gcsal.mto_contingencia     := 0;
              -- IF v_nro_cuenta IS NULL THEN
               --   rp_gcsal.sal_int_dev_no_cobrado := v_dev_no_cobrado;
            --   END IF;
               IF nvl(FUG_OBT_PARDINAMICO('TIP_DES_DOCUMENTOS', 6, rp_gcsal.cod_modalidad, null, null), 'X') in
                        ('C', 'D') and rp_gcsal.cod_modalidad <> 622/*613*/ then
                  IF rp_gcsal.sal_capital > 0 THEN
                     if i.nro_ope_original like '%#%' and v_nro_cuota is not null then
                       IF lf_es_cuo_vencida(v_nro_cuenta, v_nro_cuota) = 'S' THEN
                          rp_gcsal.mto_prevision := nvl(v_tot_prevision, 0);
                       else
                          rp_gcsal.mto_prevision := 0;
                       END IF;
                     else --cuentas de descuento de cheque sin formato con numerales
                        rp_gcsal.mto_prevision := nvl(v_tot_prevision, 0);
                     end if;
                     rp_gcsal.sal_int_dev_no_cobrado := nvl(v_dev_no_cobrado, 0);
                  END IF;
               ELSE
                 rp_gcsal.mto_prevision := nvl(v_tot_prevision, 0);
                 rp_gcsal.sal_int_dev_no_cobrado := nvl(v_dev_no_cobrado, 0);
               END IF;
               IF rp_gcsal.mto_prevision > 0 THEN
                 rp_gcsal.rub_con_prevision := pab_asi.fu_obt_rub_contable(v_nro_cuenta, 'V');
                 IF rp_gcsal.rub_con_prevision IS NULL THEN
                    rp_gcsal.rub_con_prevision := IT.pas_cri.fu_obt_cod_rubro(v_nro_cuenta,null,null, 730, null,null,null,null,1, 'C',null,v_estado,null,null,null,null,null);
                 END IF;
              ELSE
                 rp_gcsal.rub_con_prevision := NULL;
              END IF;

               IF rp_gcsal.cod_modalidad = 671 THEN
                  rp_gcsal.sal_int_dev_no_cobrado  := 0;
                  rp_gcsal.sal_int_dev_cobrado     := 0;
                  rp_gcsal.rub_con_int_dev_cobrado := NULL;
                  rp_gcsal.rub_con_dev_no_cobrado  := NULL;
               END IF;

               IF rp_gcsal.cod_modalidad = 660 THEN
                   rp_gcsal.dia_atraso := v_fec_fin - i.fec_operacion; --fieldesk 3426 se resta la fecha del proceso menos la fecha real de informacion al RCF.
               END IF;

            ELSIF i.cod_modulo = 5 THEN
              ----fieldesk-19388
              if nvl(fug_obt_pardinamico('MAD_TAR_CRE_UENO',i.cod_modulo,i.cod_modalidad),'N') = 'S' then

                 rp_gcsal.nro_operacion := i.nro_cuenta;

              end if;
              --
               lp_obt_dat_tarjeta(i.nro_cuenta,
                                  i.fecha,
                                  rp_gcsal.cod_modalidad,
                                  v_fec_apertura,
                                  rp_gcsal.sal_capital,
                                  rp_gcsal.dia_atraso,
                                  v_tip_cierre,
                                  v_tas_efectiva,
                                  v_est_tarjeta,
                                  v_fec_ult_operacion,       -- nuevo
                                  rp_gcsal.est_tarjeta,      -- nuevo
                                  rp_gcsal.mto_deu_anterior, -- nuevo
                                  rp_gcsal.mto_pag_mes,      -- nuevo
                                  rp_gcsal.mto_lin_credito,  -- nuevo
                                  rp_gcsal.mto_com_mes,      -- nuevo
                                  rp_gcsal.mto_deu_facturar, -- nuevo
                                  rp_gcsal.mto_cargo);       -- nuevo
               rp_gcsal.rub_con_contingencia := IT.pas_cri.fu_obt_cod_rubro(i.nro_cuenta,null,null, 224, null,null,null,null,null, 'D',null,null,null,null,null,null,null);
               IF rp_gcsal.rub_con_capital IS NULL THEN

                        --920 --> VIGENTE
                        --929 --> GESTION
                        --939    --> VENCIDA
                       --1510    --> MOROSO
                         IF (v_est_tarjeta = 'V') THEN
                            v_cod_transaccion := 939; --vencidas
                         END IF;
                         IF (v_est_tarjeta = 'G') THEN
                            v_cod_transaccion := 929; --en gestion
                         END IF;
                         IF (v_est_tarjeta = 'M') THEN
                            v_cod_transaccion := 1510; --morosas
                         END IF;
                         IF (v_est_tarjeta = 'C') then
                            v_cod_transaccion := 920; --vigente
                         END IF;

                  rp_gcsal.rub_con_capital := IT.pas_cri.fu_obt_cod_rubro(i.nro_cuenta,null,null, v_cod_transaccion, null,null,null,null,null, 'C',null,v_est_tarjeta,null,null,null,null,null);

               END IF;
               IF rp_gcsal.dia_atraso > 0 THEN
                  rp_gcsal.sal_cuo_vencida := nvl(rp_gcsal.sal_capital, 0);
               END IF;
               IF rp_gcsal.cod_modalidad IS NOT NULL THEN
                  IF v_cod_entidad = 6004 THEN
                     IF v_fec_apertura <
                        pat_imp.fu_obt_fec_cierre(fug_obt_pardinamico('COD_PRO_PROCARD'), rp_gcsal.cod_modalidad) THEN
                        rp_gcsal.fec_vto_cuota := pat_imp.fu_obt_fec_vencim(fug_obt_pardinamico('COD_PRO_PROCARD'),
                                                                            rp_gcsal.cod_modalidad);

                     ELSIF v_fec_apertura >=
                           pat_imp.fu_obt_fec_cierre(fug_obt_pardinamico('COD_PRO_PROCARD'), rp_gcsal.cod_modalidad) THEN
                        rp_gcsal.fec_vto_cuota := IT.pas_cri.fu_obt_sig_fec_vencimiento(fug_obt_pardinamico('COD_PRO_PROCARD'),
                                                                                     rp_gcsal.cod_modalidad,
                                                                                     v_fec_apertura);
                     END IF;
                  ELSIF v_cod_entidad = 2036 THEN
                     rp_gcsal.fec_vto_cuota := pat_imp.fu_obt_fec_vencim(fug_obt_pardinamico('COD_PRO_PROCARD'),
                                                                         rp_gcsal.cod_modalidad);
                  ELSIF v_cod_entidad = 2079 THEN
                     rp_gcsal.fec_vto_cuota := IT.pas_cri.fu_obt_sig_fec_vencimiento(fug_obt_pardinamico('COD_PRO_BANCARD'),
                                                                                  rp_gcsal.cod_modalidad,
                                                                                  v_fec_apertura);
                  ELSE
                     rp_gcsal.fec_vto_cuota := IT.pas_cri.fu_obt_sig_fec_vencimiento(fug_obt_pardinamico('COD_PRO_BANCARD'),
                                                                                  rp_gcsal.cod_modalidad,
                                                                                  v_fec_apertura,
                                                                                  v_tip_cierre);
                  END IF;
               END IF;
               IF nvl(rp_gcsal.sal_capital, 0) < 0 THEN
                  --- Si la Deuda fuera Negativa, el Saldo Capital es 0
                  rp_gcsal.sal_capital := 0;
               END IF;
               rp_gcsal.mto_prevision := nvl(v_tot_prevision, 0);
               IF rp_gcsal.mto_prevision > 0 THEN
                  rp_gcsal.rub_con_prevision := pab_asi.fu_obt_rub_contable(i.nro_cuenta, 'V');
                  IF rp_gcsal.rub_con_prevision IS NULL THEN
                     rp_gcsal.rub_con_prevision := IT.pas_cri.fu_obt_cod_rubro(i.nro_cuenta,null,null, 730, null,null,null,null,1, 'C',null,v_est_tarjeta,null,null,null,null,null);
                  END IF;
               ELSE
                  rp_gcsal.rub_con_prevision := NULL;
               END IF;
               rp_gcsal.mto_contingencia := v_tot_deu_contingente;
               IF rp_gcsal.mto_contingencia > 0 THEN
                  rp_gcsal.rub_con_contingencia := IT.pas_cri.fu_obt_cod_rubro(i.nro_cuenta,null,null, 1531, null,null,null,null,null, 'D',null,null,null,null,null,null,null);

               ELSE
                  rp_gcsal.rub_con_contingencia := NULL;
               END IF;
               rp_gcsal.can_cuo_pagadas := 0;
               -- Si la TC esta en venta de cartera, SALDOSV la reporta. No informar por modulo 5.
               SELECT COUNT(1) INTO v_en_vta_cartera
                 FROM sb_crc_vta_carteras
                WHERE nro_cuenta_bt = i.nro_cuenta
                  AND nvl(ope_recaptada, 'N') = 'N'
                  AND nvl(estado_vta_cartera, 'N') = 'C'
                  AND ROWNUM = 1;
               IF v_en_vta_cartera > 0 THEN
                  rp_gcsal.sal_capital   := NULL;
                  rp_gcsal.cod_modalidad := NULL;
               END IF;
            ELSIF i.cod_modulo = 3 THEN
               lp_obt_dat_cta_pasivas(i.nro_cuenta,
                                      i.fecha,
                                      rp_gcsal.sal_capital,
                                      rp_gcsal.cod_modalidad,
                                      v_cod_transaccion,
                                      v_estado,
                                      v_fec_ult_capitalizacion,
                                      v_cod_moneda,
                                      v_fec_ult_movimiento);  -- nuevo
               IF rp_gcsal.rub_con_capital IS NULL THEN
                  rp_gcsal.rub_con_capital := IT.pas_cri.fu_obt_cod_rubro(i.nro_cuenta,null,null, v_cod_transaccion, null,null,null,null,null, 'C',null,null,null,null,null,null,null);
               END IF;
               rp_gcsal.rub_con_int_devengar := pab_asi.fu_obt_rub_contable(i.nro_cuenta, 'A');
               IF rp_gcsal.cod_modalidad IN (33, 34) THEN
                  -- Si es CDA vencido va al rubro 138 y tipo 138
                  -- Si el CDA esta vigente pero el interes esta vencido, el interes va en la 138  y el capital vigente en la 156 ,236
                  IF rp_gcsal.cod_modalidad IN (33, 34) THEN
                     rp_gcsal.fec_vto_cuota := lf_obt_fec_vto_cuota(i.nro_cuenta);
                     IF v_estado <> 'V' THEN
                        v_int_cda_vencido := lf_obt_int_cda_vencido(i.nro_cuenta);
                        IF v_int_cda_vencido > 0 AND i.tip_operacion =  substr(v_tip_ope_cup_ven,instr(v_tip_ope_cup_ven,i.tip_operacion),3) THEN
                           rp_gcsal.rub_con_capital := lf_obt_rub_inventario(i.nro_cuenta, 'C', 'V');
                        ELSIF v_int_cda_vencido > 0 AND i.tip_operacion <> substr(v_tip_ope_cup_ven,instr(v_tip_ope_cup_ven,i.tip_operacion),3) THEN
                           rp_gcsal.sal_capital := rp_gcsal.sal_capital - v_int_cda_vencido;
                        END IF;
                     ELSIF v_estado = 'V' AND i.tip_operacion <> substr(v_tip_ope_cup_ven,instr(v_tip_ope_cup_ven,i.tip_operacion),3) AND
                           lf_ver_cta_operaciones(i.nro_ope_original) = 'S' THEN
                        rp_gcsal.sal_capital := NULL;
                     ELSIF v_estado = 'V' AND i.tip_operacion = substr(v_tip_ope_cup_ven,instr(v_tip_ope_cup_ven,i.tip_operacion),3) AND
                           lf_ver_cta_operaciones(i.nro_ope_original) = 'S' THEN
                        rp_gcsal.sal_capital := rp_gcsal.sal_capital + v_int_cda_vencido;
                     END IF;
                  END IF;
                  IF v_int_cda_vencido > 0 AND i.tip_operacion = substr(v_tip_ope_cup_ven,instr(v_tip_ope_cup_ven,i.tip_operacion),3) AND rp_gcsal.cod_modalidad IN (33, 34) AND
                     v_estado <> 'V' THEN
                     rp_gcsal.sal_capital := v_int_cda_vencido;
                  ELSIF (i.tip_operacion <> substr(v_tip_ope_cup_ven,instr(v_tip_ope_cup_ven,i.tip_operacion),3) AND lf_ver_cta_operaciones(i.nro_ope_original) = 'S') OR
                        (i.tip_operacion = substr(v_tip_ope_cup_ven,instr(v_tip_ope_cup_ven,i.tip_operacion),3)) OR
                        (i.tip_operacion <> substr(v_tip_ope_cup_ven,instr(v_tip_ope_cup_ven,i.tip_operacion),3) AND lf_ver_cta_operaciones(i.nro_ope_original) = 'N') THEN
                     rp_gcsal.sal_int_dev_cobrado := lf_obt_int_dev_acumulado(i.nro_cuenta);
                     v_sal_int_dev_cobrado        := lf_obt_int_dev_cda(i.nro_cuenta);
                     rp_gcsal.sal_int_devengar    := lf_obt_int_devengar(i.nro_cuenta,
                                                                         v_fec_ult_capitalizacion,
                                                                         v_estado);
                     IF v_estado NOT IN ('V', 'T', 'X') THEN
                        rp_gcsal.sal_int_dev_no_cobrado := abs(v_sal_int_dev_cobrado - rp_gcsal.sal_int_devengar);
                     ELSE
                        rp_gcsal.sal_int_dev_no_cobrado := 0;
                     END IF;
                     IF rp_gcsal.sal_int_devengar > 0 THEN
                        rp_gcsal.rub_con_int_devengar := pab_asi.fu_obt_rub_contable(i.nro_cuenta, 'A');
                     END IF;
                  END IF;
                  IF i.tip_operacion = substr(v_tip_ope_cup_ven,instr(v_tip_ope_cup_ven,i.tip_operacion),3) AND lf_obt_rub_inventario(i.nro_cuenta, 'C', 'V') IS NULL AND
                     v_estado <> 'V' THEN
                     rp_gcsal.sal_capital := NULL;
                  END IF;
                  IF v_estado IN ('C', 'T', 'V') THEN
                     rp_gcsal.tas_efectiva            := NULL;
                     rp_gcsal.rub_con_int_devengar    := NULL;
                     rp_gcsal.sal_int_dev_no_cobrado  := 0;
                     rp_gcsal.rub_con_int_dev_cobrado := NULL;
                     rp_gcsal.sal_int_dev_cobrado     := 0;
                  END IF;
                  IF rp_gcsal.sal_int_devengar = 0 THEN
                     rp_gcsal.rub_con_int_devengar := NULL;
                  END IF;
               ELSIF rp_gcsal.cod_modalidad in (31, 38, 39) THEN
                  IF v_estado = 'C' THEN
                     rp_gcsal.tas_efectiva := NULL;
                  END IF;
                  IF i.tip_operacion <> substr(v_tip_ope_cup_ven,instr(v_tip_ope_cup_ven,i.tip_operacion),3) OR lf_ver_cta_operaciones(i.nro_ope_original) = 'N' THEN

                     IF v_estado NOT IN ('P', 'C') AND
                        nvl(v_fec_ult_capitalizacion, to_date('01/01/1900', 'dd/mm/yyyy')) <> v_fec_fin THEN
                        rp_gcsal.sal_int_devengar := lf_obt_int_devengado(i.nro_cuenta);
                     END IF;
                     IF rp_gcsal.rub_con_int_devengar IS NULL AND rp_gcsal.sal_int_devengar > 0 THEN
                        rp_gcsal.rub_con_int_devengar := IT.pas_cri.fu_obt_cod_rubro(i.nro_cuenta,null,null, 609, null,null,null,null,null, 'D',null,null,null,null,null,null,null);
                     END IF;
                     IF rp_gcsal.sal_int_devengar > 0 THEN
                        rp_gcsal.rub_con_int_devengar   := pab_asi.fu_obt_rub_contable(i.nro_cuenta, 'D');
                        rp_gcsal.sal_int_dev_no_cobrado := rp_gcsal.sal_int_devengar;
                        rp_gcsal.rub_con_dev_no_cobrado := lf_obt_rub_padre(pab_asi.fu_obt_rub_contable(i.nro_cuenta,
                                                                                                        'D'));
                     END IF;
                     rp_gcsal.sal_int_dev_cobrado  := lf_obt_int_dev_cda(i.nro_cuenta);
                     rp_gcsal.sal_int_devengar     := 0;
                     rp_gcsal.rub_con_int_devengar := NULL;
                  END IF;
               END IF;
               IF rp_gcsal.sal_int_dev_cobrado > 0 THEN
                  rp_gcsal.rub_con_int_dev_cobrado := IT.pas_cri.fu_obt_cod_rubro(i.nro_cuenta,null,null, 901, null,null,null,null,null, 'D',null,null,null,null,null,null,null);
               END IF;
               IF rp_gcsal.sal_int_dev_no_cobrado > 0 and rp_gcsal.cod_modalidad IN (33, 34) THEN
                  rp_gcsal.rub_con_dev_no_cobrado := lf_obt_rub_padre(IT.pas_cri.fu_obt_cod_rubro(i.nro_cuenta,null,null, 901, null,null,null,null,null, 'C',null,null,null,null,null,null,null));
               end if;
               IF (v_estado IN ('C','T') and rp_gcsal.cod_modalidad IN (33, 34)) or (v_estado IN ('C') and rp_gcsal.cod_modalidad in (31, 38, 39)) THEN
                  rp_gcsal.sal_capital             := NULL;
                  rp_gcsal.tas_efectiva            := NULL;
                  rp_gcsal.can_cuo_pagadas         := 0;
                  rp_gcsal.sal_int_dev_cobrado     := 0;
                  rp_gcsal.fec_vto_cuo_vencida     := NULL;
                  rp_gcsal.fec_vto_cuota           := NULL;
                  rp_gcsal.rub_con_int_dev_cobrado := NULL;
                  rp_gcsal.rub_con_dev_no_cobrado  := NULL;
                  rp_gcsal.rub_con_int_devengar    := NULL;
                  rp_gcsal.sal_int_devengar        := 0;
                  rp_gcsal.sal_int_dev_cobrado     := 0;
                  rp_gcsal.sal_int_dev_no_cobrado  := 0;
               END IF;

           /* TN-499 CC c Sobregiro */
           ELSIF i.cod_modulo = 4 THEN
            lp_obt_dat_cta_corriente(i.nro_operacion, i.nro_ope_original, rp_gcsal.sal_capital, rp_gcsal_tot_batch,
                                     rp_gcsal_blo_batch, rp_gcsal_ret_batch, rp_gcsal.cod_modalidad,
                                     v_cod_sec_contable, v_cod_tip_deudor, v_residente, v_cod_moneda, v_estado,
                                     v_fec_ult_movimiento);  -- nuevo

            v_tip_ope_cta_cte   := NULL;
            v_sal_capital       := rp_gcsal.sal_capital;
            v_mto_pignorado     := fu_obt_mto_pignorado(rp_gcsal.cod_modalidad, i.nro_operacion);
            v_rub_con_pignorado := fu_obt_rub_con_tipo(i.nro_operacion, 'P', i.tip_operacion);
            BEGIN
               SELECT r.sit_deuda, r.sit_deuda
                 INTO v_sit_deuda, v_sit_deu_prevision
                 FROM cc_sobregiros_res r
                WHERE r.nro_cuenta = i.nro_operacion;
            EXCEPTION
               WHEN no_data_found THEN
                  v_sit_deuda         := 'S';
                  v_sit_deu_prevision := 'N';
               WHEN OTHERS THEN
                  v_sit_deuda         := NULL;
                  v_sit_deu_prevision := NULL;
            END;
            IF rp_gcsal.cod_modalidad = 41 THEN
               IF rp_gcsal.sal_capital < 0 THEN
                  IF v_sit_deuda = 'S' THEN
                     v_mto_lin_sobregiro := fuc_obt_mto_lin_sob(i.nro_operacion);
                     IF nvl(v_mto_lin_sobregiro, 0) >= abs(rp_gcsal.sal_capital) THEN
                        v_sob_con_acuerdo := rp_gcsal.sal_capital;
                        v_sob_sin_acuerdo := 0;
                     ELSIF nvl(v_mto_lin_sobregiro,0) > 0 AND nvl(v_mto_lin_sobregiro,0) < abs(rp_gcsal.sal_capital) THEN
                        v_sob_con_acuerdo := v_mto_lin_sobregiro;
                        v_sob_sin_acuerdo := rp_gcsal.sal_capital + nvl(v_mto_lin_sobregiro,0);
                     ELSE
                        v_sob_con_acuerdo := 0;
                        v_sob_sin_acuerdo := rp_gcsal.sal_capital;
                     END IF;
                  END IF;
                  lp_obt_mto_prevision(v_tot_prevision, ABS(v_sob_con_acuerdo), ABS(v_sob_sin_acuerdo), v_pre_con_acuerdo, v_pre_sin_acuerdo);

               END IF;
               v_tip_ope_cta_cte := fu_obt_tip_operacion(i.tip_operacion, 'SIB_CRC_TIP_OPE_CTA_CTE');
               v_tip_ope_pignorado := fu_obt_tip_operacion(i.tip_operacion, 'SIB_CRC_TIP_OPE_PIGNORADO');
               IF nvl(rp_gcsal.sal_capital, 0) < 0 AND v_tip_ope_cta_cte = 'S' THEN
                  IF v_rub_con_pignorado IS NULL THEN
                     rp_gcsal.sal_capital := rp_gcsal_blo_batch - v_mto_pignorado;
                  ELSE
                     rp_gcsal.sal_capital :=rp_gcsal_blo_batch; --0;
                  END IF;
                  rp_gcsal.rub_con_capital := pab_asi.fu_obt_rub_contable(i.nro_operacion, 'C', 'N');
                  rp_gcsal.mto_prevision := 0;
                  rp_gcsal.rub_con_prevision := NULL;
                  rp_gcsal.mto_contingencia := 0;
                  rp_gcsal.rub_con_contingencia := NULL;
               ELSIF nvl(rp_gcsal.sal_capital, 0) < 0 AND v_tip_ope_pignorado = 'S' THEN
                  rp_gcsal.sal_capital := v_mto_pignorado;
                  rp_gcsal.rub_con_capital := v_rub_con_pignorado;
               ELSIF nvl(rp_gcsal.sal_capital, 0) < 0 AND fu_obt_tip_operacion(i.tip_operacion, 'SIB_CRC_TIP_OPE_SOB_PER') = 'S' THEN
                  rp_gcsal.sal_capital := NVL(v_sob_con_acuerdo,0);
                  IF nvl(v_sob_con_acuerdo,0) <> 0 THEN
                     rp_gcsal.rub_con_capital := pab_asi.fu_obt_rub_contable(i.nro_operacion, 'C', 'A');
                  ELSE
                     rp_gcsal.rub_con_capital := i.cta_con_cap_original;
                  END IF;
                  rp_gcsal.mto_prevision := v_pre_con_acuerdo;
                  IF nvl(v_pre_con_acuerdo,0) > 0 THEN
                     rp_gcsal.rub_con_prevision := pab_asi.fu_obt_rub_contable(i.nro_operacion, 'V');
                     IF rp_gcsal.rub_con_prevision is null THEN
                       rp_gcsal.rub_con_prevision := fu_obt_cod_rubro(i.nro_operacion, i.cod_modulo, rp_gcsal.cod_modalidad, 730,
                                                                      v_cod_moneda, v_cod_sec_contable, v_cod_tip_deudor,
                                                                      v_residente, NULL, 'C', NULL, v_sit_deu_prevision);
                     END IF;
                  ELSE
                     rp_gcsal.rub_con_prevision := NULL;
                  END IF;
                  rp_gcsal.mto_contingencia := nvl(v_tot_deu_contingente, 0);
                  IF nvl(v_tot_deu_contingente,0) > 0 THEN
                     rp_gcsal.rub_con_contingencia := pab_asi.fu_obt_rub_contable(i.nro_operacion, 'O');
                  ELSE
                     rp_gcsal.rub_con_contingencia := NULL;
                  END IF;
               ELSIF nvl(rp_gcsal.sal_capital, 0) < 0 AND fu_obt_tip_operacion(i.tip_operacion, 'SIB_CRC_TIP_OPE_SOB_TEM') = 'S' THEN
                  IF v_sit_deuda = 'S' THEN
                     rp_gcsal.sal_capital := NVL(v_sob_sin_acuerdo,0);
                     rp_gcsal.rub_con_capital := pab_asi.fu_obt_rub_contable(i.nro_operacion, 'C', 'T');
                  END IF;
                  rp_gcsal.mto_prevision := v_pre_sin_acuerdo;
                  IF nvl(v_pre_sin_acuerdo,0) > 0 THEN
                     rp_gcsal.rub_con_prevision := pab_asi.fu_obt_rub_contable(i.nro_operacion, 'V');
                     IF rp_gcsal.rub_con_prevision is null THEN
                       rp_gcsal.rub_con_prevision := fu_obt_cod_rubro(i.nro_operacion, i.cod_modulo, rp_gcsal.cod_modalidad, 730,
                                                                      v_cod_moneda, v_cod_sec_contable, v_cod_tip_deudor,
                                                                      v_residente, NULL, 'C', NULL, v_sit_deu_prevision);
                     END IF;
                  ELSE
                     rp_gcsal.rub_con_prevision := NULL;
                  END IF;
                  rp_gcsal.mto_contingencia := 0;
                  rp_gcsal.rub_con_contingencia := NULL;
               ELSIF nvl(rp_gcsal.sal_capital, 0) >=0 AND v_tip_ope_cta_cte = 'S' THEN
                  IF v_rub_con_pignorado IS NULL THEN
                     rp_gcsal.sal_capital := rp_gcsal_tot_batch - rp_gcsal_ret_batch - v_mto_pignorado;
                  ELSE
                     rp_gcsal.sal_capital :=rp_gcsal_tot_batch-rp_gcsal_ret_batch;  ----
                  END IF;
                  rp_gcsal.rub_con_capital := pab_asi.fu_obt_rub_contable(i.nro_operacion, 'C', 'N');
               ELSIF nvl(rp_gcsal.sal_capital, 0) >=0 AND v_tip_ope_pignorado = 'S' THEN
                  rp_gcsal.sal_capital := v_mto_pignorado;
                  rp_gcsal.rub_con_capital := v_rub_con_pignorado;
               ELSIF fu_obt_tip_operacion(i.tip_operacion, 'SIB_CRC_TIP_OPE_SOBREGIRO') = 'S' AND nvl(rp_gcsal.sal_capital, 0) >= 0 then
                     rp_gcsal.sal_capital := 0;
                     rp_gcsal.rub_con_capital := i.cta_con_cap_original;
                  rp_gcsal.mto_prevision := 0;
                  rp_gcsal.rub_con_prevision := NULL;
                  rp_gcsal.tas_efectiva := 0;
                  IF fu_obt_tip_operacion(i.tip_operacion, 'SIB_CRC_TIP_OPE_SOB_PER') = 'S' THEN
                     rp_gcsal.mto_contingencia     := nvl(v_tot_deu_contingente,0);
                     rp_gcsal.rub_con_contingencia := pab_asi.fu_obt_rub_contable(i.nro_operacion, 'O');
                  ELSE
                     rp_gcsal.mto_contingencia := 0;
                     rp_gcsal.rub_con_contingencia := NULL;
                  END IF;
               END IF;

               IF rp_gcsal.rub_con_capital IS NULL THEN
                  IF v_sit_deuda = 'S' THEN
                     rp_gcsal.rub_con_capital := pab_asi.fu_obt_rub_contable(i.nro_operacion, 'C', 'A');
                     IF rp_gcsal.rub_con_capital IS NULL THEN
                        rp_gcsal.rub_con_capital := pab_asi.fu_obt_rub_contable(i.nro_operacion, 'C', 'T');
                     END IF;
                  ELSE
                     rp_gcsal.rub_con_capital := pab_asi.fu_obt_rub_contable(i.nro_operacion, 'C', v_sit_deuda);
                  END IF;
               END IF;
            ELSIF rp_gcsal.cod_modalidad = 47 THEN---Para agregar el city
               rp_gcsal.rub_con_capital := pab_asi.fu_obt_rub_contable(i.nro_operacion, 'C');
            ELSE
               rp_gcsal.rub_con_capital := pab_asi.fu_obt_rub_contable(i.nro_operacion, 'B');
            END IF;
            rp_gcsal.sal_capital := ABS(rp_gcsal.sal_capital);

            IF rp_gcsal.rub_con_capital IS NULL THEN
               rp_gcsal.rub_con_capital := fu_obt_cod_rubro(i.nro_operacion, i.cod_modulo, rp_gcsal.cod_modalidad, 602,
                                                                   v_cod_moneda, v_cod_sec_contable, v_cod_tip_deudor,
                                                                   v_residente, NULL, 'C', NULL, v_estado);
            END IF;
            IF rp_gcsal.rub_con_capital IS NULL THEN
               rp_gcsal.rub_con_capital := i.cta_con_cap_original;
            END IF;
            IF v_tip_ope_cta_cte = 'S' THEN
               rp_gcsal.tas_efectiva := 0;
               IF i.sub_tip_ope = 'EMB' THEN
                  rp_gcsal.sal_capital := v_sal_bloqueado;
                  rp_gcsal.rub_con_capital := pab_asi.fu_obt_rub_contable(i.nro_operacion, 'Q', null);
                  IF rp_gcsal.rub_con_capital IS NULL THEN
                     rp_gcsal.rub_con_capital := i.cta_con_cap_original;
                  END IF;
               ELSE
                  rp_gcsal.sal_capital := rp_gcsal.sal_capital - v_sal_bloqueado;
               END IF;
            END IF;
            rp_gcsal.tip_operacion       := i.tip_operacion;
            rp_gcsal.nro_operacion       := i.nro_ope_original;
            rp_gcsal.fec_corte           := v_fec_fin;
            lp_obt_can_dia_sobregiro(i.nro_operacion, rp_gcsal.dia_atraso); --- dia de sobregiro
            if v_cod_sec_contable ='P' and rp_gcsal.cod_modalidad=41 and nvl(v_sal_capital, 0) < 0 then
              rp_gcsal.fec_vto_cuota       := v_fec_actual-rp_gcsal.dia_atraso;
              rp_gcsal.fec_vto_cuo_vencida := v_fec_actual-rp_gcsal.dia_atraso;
              rp_gcsal.sal_cuo_vencida         := rp_gcsal.sal_capital;
            else
              rp_gcsal.fec_vto_cuota       := NULL;
              rp_gcsal.fec_vto_cuo_vencida := NULL;
              rp_gcsal.sal_cuo_vencida         := 0;
            end if;

            rp_gcsal.rub_con_int_devengar    := NULL;
            rp_gcsal.sal_int_devengar        := 0;
            rp_gcsal.rub_con_dev_no_cobrado  := NULL;
            rp_gcsal.sal_int_dev_no_cobrado  := 0;
            rp_gcsal.rub_con_int_dev_cobrado := NULL;
            rp_gcsal.sal_int_dev_cobrado     := 0;
            rp_gcsal.rub_con_dev_suspenso    := NULL;
            rp_gcsal.sal_int_suspenso        := 0;
            IF ((v_sal_capital >= 0 AND rp_gcsal.cod_modalidad = 41 AND v_tip_ope_cta_cte = 'S') OR
                (rp_gcsal.cod_modalidad <> 41)) THEN
               rp_gcsal.mto_prevision        := nvl(v_tot_prevision, 0);
               IF rp_gcsal.mto_prevision > 0 THEN
                  rp_gcsal.rub_con_prevision := pab_asi.fu_obt_rub_contable(i.nro_operacion, 'V');
               ELSE
                  rp_gcsal.rub_con_prevision := NULL;
               END IF;
               rp_gcsal.mto_contingencia     := 0;
               rp_gcsal.rub_con_contingencia := NULL;
            END IF;
            IF rp_gcsal.rub_con_prevision IS NULL AND rp_gcsal.mto_prevision > 0 THEN
               rp_gcsal.rub_con_prevision := fu_obt_cod_rubro(i.nro_operacion, i.cod_modulo, rp_gcsal.cod_modalidad, 730,
                                                                      v_cod_moneda, v_cod_sec_contable, v_cod_tip_deudor,
                                                                      v_residente, NULL, 'C', NULL, v_estado);
            END IF;
            IF rp_gcsal.rub_con_contingencia IS NULL AND rp_gcsal.mto_contingencia > 0 THEN
               rp_gcsal.rub_con_contingencia := fu_obt_cod_rubro(i.nro_operacion, i.cod_modulo, rp_gcsal.cod_modalidad, 920,
                                                                         v_cod_moneda, v_cod_sec_contable, v_cod_tip_deudor,
                                                                         v_residente, NULL, 'D', NULL, v_estado);
            END IF;
            IF rp_gcsal.cod_modalidad = 41 THEN
               IF v_tip_ope_pignorado = 'S' OR i.sub_tip_ope = 'EMB' THEN
                  rp_gcsal.mto_prevision := 0;
                  rp_gcsal.rub_con_prevision := NULL;
                  rp_gcsal.mto_contingencia := 0;
                  rp_gcsal.rub_con_contingencia := NULL;
                  rp_gcsal.tas_efectiva := 0;
               END IF;
               /*IF v_estado = 'I' THEN
                  rp_gcsal.mto_contingencia := 0;
                  rp_gcsal.rub_con_contingencia := NULL;
               END IF;*/
            END IF;
            rp_gcsal.can_cuo_pagadas  := 0;
            v_mto_lin_sobregiro := NULL;
            v_sob_sin_acuerdo   := NULL;
            v_sob_con_acuerdo   := NULL;
            v_pre_sin_acuerdo   := NULL;
            v_pre_con_acuerdo   := NULL;

            ELSIF i.cod_modulo = 8 THEN
               lp_obt_dat_comex(i.nro_cuenta, i.fecha, rp_gcsal.cod_modalidad, rp_gcsal.fec_vto_cuota, v_estado);
               IF rp_gcsal.rub_con_capital IS NULL THEN
                  IF v_estado = 'C' THEN
                     rp_gcsal.rub_con_capital := i.cta_con_cap_original;
                  ELSE
                     rp_gcsal.rub_con_capital := IT.pas_cri.fu_obt_cod_rubro(i.nro_cuenta,null,null, 874, null,null,null,null,1, 'D',null,null,null,null,null,null,null);
                  END IF;
               END IF;
               rp_gcsal.rub_con_prevision := pab_asi.fu_obt_rub_contable(i.nro_cuenta, 'V');
               rp_gcsal.mto_prevision     := nvl(v_tot_prevision, 0);
               rp_gcsal.mto_contingencia  := nvl(v_tot_deu_contingente, 0);
               IF rp_gcsal.mto_contingencia > 0 THEN
                  IF v_estado = 'U' THEN
                     rp_gcsal.rub_con_contingencia := IT.pas_cri.fu_obt_cod_rubro(i.nro_cuenta,null,null, 891, null,null,null,null,1, 'C',null,v_estado,null,null,null,null,null);
                  ELSIF v_estado = 'A' THEN
                     rp_gcsal.rub_con_contingencia := IT.pas_cri.fu_obt_cod_rubro(i.nro_cuenta,null,null, 874, null,null,null,null,1, 'D',null,v_estado,null,null,null,null,null);
                  ELSE
                     rp_gcsal.rub_con_contingencia := NULL;
                  END IF;
               ELSE
                  rp_gcsal.rub_con_contingencia := NULL;
               END IF;
               IF rp_gcsal.mto_prevision > 0 THEN
                  rp_gcsal.rub_con_prevision := IT.pas_cri.fu_obt_cod_rubro(i.nro_cuenta,null,null, 456, null,null,null,null,1, 'D',null,v_estado,null,null,null,null,null);
               ELSE
                  rp_gcsal.rub_con_prevision := NULL;
               END IF;
            ELSIF i.cod_modulo = 15 THEN
               --- Busca el saldo segun Inventario
               pav_ove.pr_ini_modulo;
               pav_ove.pr_ini_autorizacion;
               pav_ove.pr_obt_deu_ope_vencida(i.nro_cuenta,
                                              v_fec_actual,
                                              v_cobrado,
                                              v_error,
                                              v_men_ope_vencida,
                                              rp_gcsal.sal_capital,
                                              v_tot_mora,
                                              v_tot_punitorio,
                                              v_tot_impuesto,
                                              v_tot_cargo,
                                              v_tot_car_iva,
                                              v_dia_mora,
                                              v_cod_tra_padre);

               COMMIT;
               --se ajustan valores de ope vencidas a la operacion original reportada
               begin
                 select v.nro_cta_origen
                 into v_nro_ope_ori_vencida
                 from ov_cta_vencidas v
                 where v.nro_cuenta = i.nro_cuenta;
               exception
                 when no_data_found then
                   v_nro_ope_ori_vencida := null;
               end;
              if v_nro_ope_ori_vencida is not null then --MODIFICAR para Ope Vencidas Mod 53

                    begin
                     select t.cod_modulo,t.cod_modalidad
                      into v_cod_modulo, v_cod_modalidad
                     from ta_cta_tarjetas t
                     where t.nro_cuenta = v_nro_ope_ori_vencida;

                   exception
                     when no_data_found then
                      v_cod_modulo := null;
                      v_cod_modalidad := null ;
                   end;

                  -- if nvl(fug_obt_pardinamico('MAD_TAR_CRE_UENO',i.cod_modulo,i.cod_modalidad),'N') = 'S' then --FIELDESK-19388 informar nro_Cuenta en lugar de plasitco si es duo
                  if nvl(fug_obt_pardinamico('MAD_TAR_CRE_UENO',v_cod_modulo, v_cod_modalidad),'N') = 'S' then
                   -- Tarjeta DUO: sin cambio
                   begin
                     select v_nro_ope_ori_vencida,o.tip_operacion, o.cod_oficina
                     into v_nro_ope_vencida, v_tip_ope_vencida, v_cod_ofi_vencida
                     from sb_crc_operaciones_det o
                     where o.nro_operacion = v_nro_ope_ori_vencida;
                   exception
                     when no_data_found then
                       v_nro_ope_vencida := null;
                       v_tip_ope_vencida := null;
                       v_cod_ofi_vencida := null;
                   end;
                  elsif v_cod_modulo is null then -- RAMA NUEVA: Sobregiro / Cta Corriente (BUG rubro 1603027502)
                   begin
                     -- Si la cuenta origen tiene mas de un registro en sb_crc_operaciones_det
                     -- (p.ej. 136 pasivo normal y 187/189 activo/sobregiro), priorizar
                     -- siempre el tip_operacion de sobregiro (187, luego 189) sobre cualquier otro.
                     select v_nro_ope_ori_vencida,o.tip_operacion, o.cod_oficina
                     into v_nro_ope_vencida, v_tip_ope_vencida, v_cod_ofi_vencida
                     from sb_crc_operaciones_det o
                     where o.nro_operacion = v_nro_ope_ori_vencida
                     order by case when o.tip_operacion = 187 then 0
                                   when o.tip_operacion = 189 then 1
                                   else 2 end
                     fetch first 1 row only;
                   exception
                     when no_data_found then
                       v_nro_ope_vencida := null;
                       v_tip_ope_vencida := null;
                       v_cod_ofi_vencida := null;
                   end;
                  ELSE
                   -- Tarjeta regular (no DUO): sin cambio
                   begin
                     select t.nro_tarjeta,o.tip_operacion, o.cod_oficina
                     into v_nro_ope_vencida, v_tip_ope_vencida, v_cod_ofi_vencida
                     from ta_tarjetas t,sb_crc_operaciones_det o
                     where t.nro_cuenta = v_nro_ope_ori_vencida
                     and o.nro_operacion = t.nro_tarjeta;
                   exception
                     when no_data_found then
                       v_nro_ope_vencida := null;
                       v_tip_ope_vencida := null;
                       v_cod_ofi_vencida := null;
                   end;
                  end if;
               end if;
               ----------------------------------------------------------------------
               v_cod_ofi_procesada    := rp_gcsal.cod_oficina;
               v_tip_ope_procesada    := rp_gcsal.tip_operacion;
               v_nro_ope_procesada    := rp_gcsal.nro_operacion ;
               v_con_mon_iso          := rp_gcsal.con_mon_iso;

               rp_gcsal.cod_oficina   := v_cod_ofi_vencida;
               rp_gcsal.tip_operacion := v_tip_ope_vencida;
               rp_gcsal.nro_operacion := v_nro_ope_vencida;

               lp_obt_dat_ope_vencida(i.nro_cuenta, i.fecha, rp_gcsal.cod_modalidad, rp_gcsal.dia_atraso, v_estado, v_fec_ult_movimiento);
               IF v_estado = 'C' THEN
                  rp_gcsal.rub_con_capital := i.cta_con_cap_original;
               END IF;
               IF nvl(rp_gcsal.dia_atraso, 0) > 0 THEN
                  rp_gcsal.sal_cuo_vencida     := rp_gcsal.sal_capital;
                  rp_gcsal.fec_vto_cuo_vencida := v_fec_fin - nvl(rp_gcsal.dia_atraso, 0);
                  rp_gcsal.fec_vto_cuota       := rp_gcsal.fec_vto_cuo_vencida;
               END IF;
               IF v_estado = 'I' THEN
                  rp_gcsal.cla_riesgo := '6';
               END IF;
               rp_gcsal.rub_con_prevision := pab_asi.fu_obt_rub_contable(i.nro_cuenta, 'V');
               rp_gcsal.mto_prevision     := v_tot_prevision;
               rp_gcsal.mto_contingencia  := v_tot_deu_contingente;
            ELSIF i.cod_modulo = 10 THEN
               lp_obt_dat_mes_dinero(i.nro_cuenta,
                                     i.fecha,
                                     rp_gcsal.sal_capital,
                                     rp_gcsal.sal_int_devengar,
                                     rp_gcsal.cod_modalidad,
                                     rp_gcsal.dia_atraso,
                                     rp_gcsal.sal_int_dev_cobrado,
                                     rp_gcsal.rub_con_int_dev_cobrado,
                                     rp_gcsal.rub_con_dev_no_cobrado,
                                     v_estado,
                                     rp_gcsal.sal_int_dev_no_cobrado);
               IF rp_gcsal.cod_modalidad IN (100, 101, 120, 122, 127, 114, 125, 117, 119, 112, 115, 109, 110, 116) THEN
                  v_tip_movimiento  := 'D';
                  v_cod_transaccion := 711;
               ELSIF rp_gcsal.cod_modalidad IN (118) THEN
                  v_tip_movimiento  := 'C';
                  v_cod_transaccion := 801;
               ELSIF rp_gcsal.cod_modalidad IN (126) THEN
                  v_tip_movimiento  := 'C';
                  v_cod_transaccion := 904;
               END IF;

               IF rp_gcsal.rub_con_capital IS NULL THEN
                  rp_gcsal.rub_con_capital := IT.pas_cri.fu_obt_cod_rubro(i.nro_cuenta,null,null, v_cod_transaccion, null,null,null,null,null, v_tip_movimiento,null,null,null,null,null,null,null);
               END IF;
               IF v_estado = 'N' THEN
                  rp_gcsal.rub_con_capital := i.cta_con_cap_original;
               END IF;
               lp_obt_dat_cuentas(v_fec_fin,
                                  i.nro_cuenta,
                                  i.cod_modulo,
                                  rp_gcsal.fec_vto_cuota,
                                  rp_gcsal.fec_vto_cuo_vencida,
                                  rp_gcsal.sal_cuo_vencida);
               IF v_dev_no_cobrado <> 0 THEN
                  rp_gcsal.sal_int_dev_no_cobrado := v_dev_no_cobrado;
               ELSE
                  v_cotizacion                    := nvl(fug_obt_cotizacion(rp_gcsal.con_mon_iso, v_fec_fin), 1);
                  rp_gcsal.sal_int_dev_no_cobrado := round(rp_gcsal.sal_int_dev_no_cobrado * v_cotizacion, v_redondeo);
               END IF;
               rp_gcsal.mto_prevision    := v_tot_prevision;
               rp_gcsal.mto_contingencia := v_tot_deu_contingente;
               IF rp_gcsal.cod_modalidad IN (122) THEN
                  v_tip_movimiento  := 'D';
                  v_cod_transaccion := 903;
               ELSIF rp_gcsal.cod_modalidad IN (127) THEN
                  v_tip_movimiento  := 'D';
                  v_cod_transaccion := 903;
               ELSIF rp_gcsal.cod_modalidad IN (100, 101, 114, 116, 116, 135) THEN
                  v_tip_movimiento  := 'C';
                  v_cod_transaccion := 719;
               ELSIF rp_gcsal.cod_modalidad IN (117, 118, 115, 109) THEN
                  v_tip_movimiento  := 'C';
                  v_cod_transaccion := 901;
               ELSIF rp_gcsal.cod_modalidad IN (119) THEN
                  v_tip_movimiento  := 'D';
                  v_cod_transaccion := 802;
               ELSIF rp_gcsal.cod_modalidad IN (112) THEN
                  v_tip_movimiento  := 'C';
                  v_cod_transaccion := 803;
               ELSIF rp_gcsal.cod_modalidad IN (125) THEN
                  v_tip_movimiento  := 'D';
                  v_cod_transaccion := 719;
               ELSIF rp_gcsal.cod_modalidad IN (126) THEN
                  v_tip_movimiento  := 'D';
                  v_cod_transaccion := 711;
               END IF;
               IF rp_gcsal.sal_int_devengar > 0 THEN
                  rp_gcsal.rub_con_int_devengar := pab_asi.fu_obt_rub_contable(i.nro_cuenta, 'A');
                  IF rp_gcsal.rub_con_int_devengar IS NULL THEN
                     rp_gcsal.rub_con_int_devengar := IT.pas_cri.fu_obt_cod_rubro(i.nro_cuenta,null,null, v_cod_transaccion, null,null,null,null,null, v_tip_movimiento,null,null,null,null,null,null,null);
                  END IF;
               END IF;
               rp_gcsal.can_cuo_pagadas := lf_obt_can_cuo_cancelada(i.nro_cuenta);
            END IF;
         END IF;
         --
         IF i.tip_operacion = '183' and i.cod_modalidad <> '660' THEN
            lp_obt_dat_ope_cheque(i.nro_ope_original,
                                  i.fecha,
                                  rp_gcsal.sal_capital,
                                  rp_gcsal.cod_modalidad,
                                  rp_gcsal.fec_vto_cuota);
            IF rp_gcsal.rub_con_capital IS NULL THEN
               rp_gcsal.rub_con_capital := i.cta_con_cap_original;
            END IF;

            rp_gcsal.mto_prevision           := 0;
            rp_gcsal.mto_contingencia        := 0;
            rp_gcsal.sal_int_devengar        := 0;
            rp_gcsal.sal_int_dev_cobrado     := 0;
            rp_gcsal.sal_int_dev_no_cobrado  := 0;
            rp_gcsal.sal_int_suspenso        := 0;
            rp_gcsal.sal_cuo_vencida         := 0;
            rp_gcsal.rub_con_prevision       := null;
            rp_gcsal.rub_con_contingencia    := null;
            rp_gcsal.rub_con_int_devengar    := null;
            rp_gcsal.rub_con_int_dev_cobrado := null;
            rp_gcsal.rub_con_dev_suspenso    := null;
            rp_gcsal.rub_con_dev_no_cobrado  := null;
            rp_gcsal.tas_efectiva            := null;
            rp_gcsal.dia_atraso              := 0;
         END IF;


         IF rp_gcsal.sal_capital < 0 THEN
            v_mensaje := v_mensaje || ', Saldo Capital NEGATIVO';
         ELSIF ((v_estado = 'N' AND rp_gcsal.cod_modulo IN (6, 10))
           OR   (v_estado = 'C' AND rp_gcsal.cod_modulo IN (3, 5, 4))) AND rp_gcsal.sal_capital > 0 THEN
            v_mensaje := v_mensaje || ', Cuenta Cancelada con Saldo';
         END IF;
         IF rp_gcsal.rub_con_int_dev_cobrado IS NULL AND rp_gcsal.sal_int_dev_cobrado > 0 THEN
            v_mensaje := v_mensaje || ', Rubro Contable Interes Dev. Cobrado Nulo con Saldo de Int. Dev. Cobrado';
         END IF;
         IF rp_gcsal.rub_con_int_devengar IS NULL AND rp_gcsal.sal_int_devengar > 0 THEN
            v_mensaje := v_mensaje || ', Rubro Contable Interes a devengar Nulo con Saldo de Int. a Devengar';
         END IF;
         IF rp_gcsal.rub_con_dev_suspenso IS NULL AND rp_gcsal.sal_int_suspenso > 0 THEN
            v_mensaje := v_mensaje || ', Rubro Contable Devengado en Suspenso Nulo con Saldo de Int. Suspenso';
         END IF;
         IF rp_gcsal.rub_con_contingencia IS NULL AND rp_gcsal.mto_contingencia > 0 THEN
            v_mensaje := v_mensaje || ', Rubro Contable Contingencia Nulo con Saldo de Contingencia';
         END IF;
         IF rp_gcsal.rub_con_prevision IS NULL AND rp_gcsal.mto_prevision > 0 THEN
            v_mensaje := v_mensaje || ', Rubro Contable Prevision Nulo con Saldo de Prevision';
         END IF;
         IF rp_gcsal.sal_cuo_vencida = 0 AND rp_gcsal.dia_atraso > 0 THEN
            v_mensaje := v_mensaje || ', Saldo cuota vencida no puede ser Cero si tiene dias de atraso.';
         END IF;
         -- Inserta los saldos solo si devuelve un saldo capital, recuperado por cada procedimiento
         -- por ejemplo lp_obt_dat_prestamo, de lo contrario significa que la cuenta ya esta
         -- cancelada

         IF rp_gcsal.sal_capital is not null and rp_gcsal.cod_modalidad is not null then
            IF i.cod_modulo!=6 then  --> SE EXCLUYE EL MODULO 6 DEL CALCULO DE LA TASA EFECTIVA
                IF substr(rp_gcsal.rub_con_capital,6,5) = '13804' THEN
                    BEGIN
                        -- Busco cuenta credito
                        SELECT A.nro_cta_credito
                          INTO v_cta_credito
                          FROM ah_cta_certificados A
                          JOIN ah_cta_vistas B ON A.nro_cta_credito = B.nro_cuenta
                         WHERE A.nro_cuenta = i.nro_cuenta;

                        -- tiene cuenta credito que es ahorro vista
                        rp_gcsal.tas_efectiva := fus_obt_tas_efectiva(v_cta_credito);
                    EXCEPTION
                        WHEN OTHERS THEN
                            --No tengo cuenta credito, o tengo pero corresponde a una CC
                           rp_gcsal.tas_efectiva := null;
                    END;

                    IF rp_gcsal.tas_efectiva is null THEN

                      BEGIN
                        select tas_interes
                                 into v_tas_minima
                                 from cr_piz_plazos
                                where cod_modalidad = 31
                                  AND COD_SUB_MODALIDAD = 1
                                  AND TIP_CAPITALIZACION = 1
                                  AND COD_MONEDA IN (i.cod_moneda,
                                                    (SELECT cod_moneda FROM ba_monedas WHERE cod_mon_iso = i.cod_moneda)
                                                );
                               rp_gcsal.tas_efectiva := v_tas_minima;
                      EXCEPTION
                        WHEN OTHERS THEN
                           rp_gcsal.tas_efectiva := null;
                      END;
                    END IF;
                ELSIF  rp_gcsal.tas_efectiva IS NULL THEN
                   rp_gcsal.tas_efectiva := 0;
                ELSIF it.pas_cri.fu_obt_tip_operacion(rp_gcsal.Tip_Operacion, 'SIB_CRC_TIP_OPE_CTA_CTE') = 'S' THEN
                      rp_gcsal.tas_efectiva := 0;
                ELSIF nvl(fup_obt_tip_descuento(rp_gcsal.cod_modalidad), 'X') NOT IN ('D', 'C') THEN
                   rp_gcsal.tas_efectiva := nvl(fus_obt_tas_efectiva(i.nro_cuenta), 0);
                ELSIF nvl(fup_obt_tip_descuento(rp_gcsal.cod_modalidad), 'X') IN ('D', 'C') AND nvl(rp_gcsal.tas_efectiva, 0) = 0 THEN
                   rp_gcsal.tas_efectiva := nvl(fus_obt_tas_efectiva(i.nro_cuenta), 0);
                END IF;

                IF rp_gcsal.tas_efectiva > 50 THEN
                   v_mensaje := v_mensaje || ', Tasa efectiva superior a 50%';
                END IF;
           ELSE
              rp_gcsal.tas_efectiva := 0;
           END IF; --> FIN DE LA EXCLUSION
            v_cat_riesgo := fue_obt_des_refcodes('CAT_RIE_BCP', replace(v_cat_automatica, ',', '.'));
            IF upper(v_cat_riesgo) like upper('%Referencia%Sistema%') THEN
               v_cat_riesgo := fue_obt_des_refcodes('CAT_RIE_BCP', replace(v_cat_automatica, '.', ','));
            END IF;
            IF rp_gcsal.cla_riesgo <> 6 THEN
               IF i.cod_modulo = 6 AND  v_nro_cheque IS NOT NULL THEN
                  IF lf_es_cuo_vencida(v_nro_cuenta, v_nro_cuota) = 'S' THEN
                     rp_gcsal.cla_riesgo := v_cat_riesgo;
                  ELSE
                     rp_gcsal.cla_riesgo := 1;
                  END IF;
               ELSE
                  rp_gcsal.cla_riesgo := v_cat_riesgo;
               END IF;
            END IF;
            -- Calcular ind_movimiento (Solo aplica al archivo de saldos mensual)
            IF v_periodo = 'M' THEN
               IF i.cod_modulo = 5 OR rp_gcsal.tip_operacion = '205' THEN
                  IF v_fec_ult_operacion IS NOT NULL AND
                     to_char(v_fec_ult_operacion, 'mmyyyy') = to_char(v_fec_fin, 'mmyyyy') THEN
                     rp_gcsal.ind_movimiento := 'S';
                  ELSE
                     rp_gcsal.ind_movimiento := 'N';
                  END IF;
               ELSIF i.cod_modulo = 15 OR
                     substr(rp_gcsal.rub_con_capital, 6, 3) IN ('102','196','136','138','148','236','238','280','284','290','292','205') THEN
                  IF v_fec_ult_movimiento IS NOT NULL AND
                     to_char(v_fec_ult_movimiento, 'mmyyyy') = to_char(v_fec_fin, 'mmyyyy') THEN
                     rp_gcsal.ind_movimiento := 'S';
                  ELSE
                     rp_gcsal.ind_movimiento := 'N';
                  END IF;
               ELSE
                  rp_gcsal.ind_movimiento := NULL;
               END IF;
            END IF;
            --
            -- Limpiar campos de tarjeta si tipo de operacion no es 205
            IF NVL(rp_gcsal.tip_operacion, '0') <> '205' THEN
               rp_gcsal.est_tarjeta      := NULL;
               rp_gcsal.mto_deu_anterior := NULL;
               rp_gcsal.mto_pag_mes      := NULL;
               rp_gcsal.mto_com_mes      := NULL;
               rp_gcsal.mto_deu_facturar := NULL;
               rp_gcsal.mto_cargo        := NULL;
               rp_gcsal.mto_lin_credito  := NULL;
            END IF;
            --
            -- OBS 2: Tarjeta nueva sin extracto (dada de alta en el mes del proceso)
            IF rp_gcsal.tip_operacion = '205' AND
               to_char(v_fec_apertura, 'mmyyyy') = to_char(v_fec_fin, 'mmyyyy') THEN
               SELECT COUNT(1) INTO v_tiene_extracto
                 FROM ta_ext_cli_cab_gp
                WHERE nro_cuenta = i.nro_cuenta
                  AND fec_cierre <= v_fec_fin
                  AND ROWNUM = 1;
               IF v_tiene_extracto = 0 THEN
                  rp_gcsal.est_tarjeta      := 1;
                  rp_gcsal.mto_deu_anterior := 0;
                  rp_gcsal.mto_pag_mes      := 0;
                  rp_gcsal.mto_com_mes      := 0;
                  rp_gcsal.mto_deu_facturar := 0;
                  rp_gcsal.mto_cargo        := 0;
               END IF;
            END IF;

            -- OBS 1: Tarjeta vencida modulo 15 modalidad 151/154
            IF i.cod_modulo = 15 AND rp_gcsal.cod_modalidad IN (151, 154) THEN
               rp_gcsal.ind_movimiento   := 'N';
               rp_gcsal.est_tarjeta      := 2;
               rp_gcsal.mto_deu_anterior := 0;
               rp_gcsal.mto_pag_mes      := 0;
               rp_gcsal.mto_com_mes      := 0;
               rp_gcsal.mto_deu_facturar := 0;
               rp_gcsal.mto_cargo        := 0;
               rp_gcsal.mto_lin_credito  := 0;
            END IF;

            -- Limpiar ind_movimiento para modulo 15 modalidad 153 sin tip_operacion
            IF i.cod_modulo = 15 AND rp_gcsal.cod_modalidad = 153
               AND rp_gcsal.tip_operacion IS NULL THEN
               rp_gcsal.ind_movimiento := NULL;
            END IF;

            -- inserta el registro.
            v_nro_registro        := v_nro_registro + 1;
            rp_gcsal.nro_registro := v_nro_registro;
            lp_ins_crc_saldos(rp_gcsal);

            if i.cod_modulo = 15 or i.cod_modulo = 6  then
               rp_gcsal.cod_oficina:= v_cod_ofi_procesada;
               rp_gcsal.tip_operacion:=v_tip_ope_procesada;
               rp_gcsal.nro_operacion := v_nro_ope_procesada;
               rp_gcsal.con_mon_iso := v_con_mon_iso;
            end if;

         END IF; --insser saldos
         --Inserta log de errores
         IF v_mensaje IS NOT NULL THEN
            rp_slcrc.fecha          := v_fec_fin;
            rp_slcrc.nom_referencia := 'SALDOS';
            rp_slcrc.usu_insercion  := substr(USER, 1, 10);
            rp_slcrc.fec_insercion  := SYSDATE;
            rp_slcrc.mensaje        := 'ERROR: Nro. Operacion = ' || rp_gcsal.nro_operacion || ': ' || v_mensaje ||
                                       '; Nro. Registro: ' || rp_gcsal.nro_registro;
            rp_slcrc.nro_registro   := rp_gcsal.nro_registro;
            lp_log_crc(rp_slcrc);
         END IF;
       exception when others then
        rp_slcrc.fecha          := v_fec_fin;
        rp_slcrc.nom_referencia := 'SALDOS';
        rp_slcrc.usu_insercion  := substr(USER, 1, 10);
        rp_slcrc.fec_insercion  := SYSDATE;
        rp_slcrc.mensaje        := 'ERROR: Nro. Operacion = ' || rp_gcsal.NRO_OPERACION || DBMS_UTILITY.FORMAT_ERROR_BACKTRACE || ' - '||sqlerrm;
        rp_slcrc.nro_registro   := rp_gcsal.nro_registro;
        lp_log_crc(rp_slcrc);
      end;

         BEGIN
         insert into it.sb_crc_ope_det_proc (NRO_OPERACION, TIP_OPERACION, CON_MON_ISO, COD_OFICINA)
            values (rp_gcsal.nro_operacion,
            rp_gcsal.tip_operacion,
            rp_gcsal.con_mon_iso,
            rp_gcsal.cod_oficina);

            commit;
          EXCEPTION WHEN OTHERS THEN
             NULL;
          END;

        END LOOP;
        CLOSE c_saldos;

      dbms_output.put_line( 'No hay mas registros para el modulo: ' || m.column_value);
      PRG_INS_LOG_PROGRAMAS('PAS_CRI.SALDOS',systimestamp ||' Fin Modulo: '|| m.column_value, null, null);
      END LOOP;
      -- Venta de cartera. --
      -- pr_crc_vta_cartera(v_periodo);--se reemplaza pr_crc_gen_vta_cartera
      -- totalizo las tablas de detalles en las cabeceras respectivas.
      lp_act_tot_registro(v_fec_fin, 'SB_CRC_SALDOS');
      commit;
   END;
    -- Procedimientos que contiene los datos exigidos para el m?dulo de Pr?stamos
   PROCEDURE lp_obt_dat_cta_bancarias(p_cod_persona      IN ge_cla_operaciones.cod_persona%TYPE,
                                      p_sal_capital      OUT ge_cla_operaciones.tot_deu_real%TYPE,
                                      p_exi_cta_bancaria OUT VARCHAR2) IS
   BEGIN
      SELECT SUM(abs(nvl(sal_tot_batch, 0) - nvl(sal_ret_batch, 0)) *
                  decode(a.cod_moneda,
                         v_cod_mon_local,
                         1,
                         pag_gen.fu_obt_mon_fuerte,
                         pag_gen.fu_obt_cotizacion(pag_gen.fu_obt_mon_fuerte, v_fec_fin),
                         pag_gen.fu_obt_cotizacion(a.cod_moneda, v_fec_fin))) sal_capital
        INTO p_sal_capital
        FROM ge_clientes d, ge_cta_clientes b, cc_cta_bancarias a, ge_bancos c
       WHERE a.nro_cuenta = b.nro_cuenta
         AND b.cod_persona = d.cod_persona
         AND a.cod_modalidad = 43
         AND a.est_batch NOT IN ('C', 'X')
         AND relacion = 'P'
         AND nvl(sal_tot_batch, 0) - nvl(sal_ret_batch, 0) > 0
         AND a.cod_banco = c.cod_banco
         AND v_inc_cta_bancarias = 'S'
         AND c.cod_persona <> v_cod_per_bco_central
         AND c.cod_persona = p_cod_persona
       GROUP BY c.cod_persona;

      p_exi_cta_bancaria := 'S';

   EXCEPTION
      WHEN OTHERS THEN
         p_sal_capital      := 0;
         p_exi_cta_bancaria := 'N';
   END;

    -- Procedimiento de generacion de ge_clientes_nov Sobrecargado para insertar en BULK
   PROCEDURE lp_ins_clientes_nov (recCliNov IN cursorCliOp_type) IS
   l_error_count number;
   BEGIN

      FORALL i IN 1 .. recCliNov.count --SAVE EXCEPTIONS
          INSERT INTO ge_clientes_nov
             (cod_persona, fec_cam_clasificacion, cat_rie_anterior, cat_rie_actual)
          VALUES
             (recCliNov(i).cod_persona, recCliNov(i).fec_cam_clasificacion, recCliNov(i).cat_rie_anterior, recCliNov(i).cat_rie_actual);

        EXCEPTION WHEN OTHERS THEN
        raise_application_error(-20000,  'ERROR insertando en ge_clientes_nov ' || SQLERRM);
     END;

        -- Procedimiento carga de temporales para CRC Clasifica
   PROCEDURE lp_crc_cla_ins_tmp (fec_ant_categoria IN ge_calendarios.fec_anterior%TYPE) IS
   BEGIN

      insert into ge_cla_operaciones_cla_tmp (cat_automatica, cod_persona, cod_modalidad, nro_cuenta)
         SELECT  s.cat_automatica, s.cod_persona, s.cod_modalidad, s.nro_cuenta
             FROM ge_cla_operaciones s
            WHERE 1=1
              AND (
                   (EXISTS (SELECT 1
                             FROM ge_par_dinamicos p
                            WHERE p.parametro IN ('PRE_MAD_EXC_PYMES', 'PRE_MAD_EXCEPCION')
                              AND p.cod_modalidad = s.cod_modalidad
                              AND p.cod_modulo = s.cod_modulo
                              AND nvl(p.val_parametro, 'N') = 'S') AND NOT EXISTS
                   (SELECT 1 -- todos los miembros tienen solo ope de ME.
                      FROM ge_cla_operaciones cla
                     WHERE s.cod_persona = cla.cod_persona
                       AND NOT EXISTS (SELECT 1
                              FROM ge_par_dinamicos p
                             WHERE p.parametro IN ('PRE_MAD_EXC_PYMES', 'PRE_MAD_EXCEPCION')
                               AND p.cod_modalidad = cla.cod_modalidad
                               AND p.cod_modulo = cla.cod_modulo
                               AND nvl(p.val_parametro, 'N') = 'S'))) OR --no es de medida transitoria
                   --2
                   (NOT EXISTS (SELECT 1
                                 FROM ge_par_dinamicos p
                                WHERE p.parametro IN ('PRE_MAD_EXC_PYMES', 'PRE_MAD_EXCEPCION')
                                  AND p.cod_modalidad = s.cod_modalidad
                                  AND p.cod_modulo = s.cod_modulo
                                  AND nvl(p.val_parametro, 'N') = 'S')
                         AND NOT EXISTS (SELECT 1
                                           FROM ge_cta_dat_adicionales a
                                          WHERE a.parametro IN ('PRE_RRR_CTA_MBT','PRE_RRR_CTA_MBT1','PRE_RRR_CTA_MBT2')
                                            AND a.nro_cuenta = s.nro_cuenta)) OR
                   --3
                   (NOT EXISTS (SELECT 1
                                 FROM ge_par_dinamicos p
                                WHERE p.parametro IN ('PRE_MAD_EXC_PYMES', 'PRE_MAD_EXCEPCION')
                                  AND p.cod_modalidad = s.cod_modalidad
                                  AND p.cod_modulo = s.cod_modulo
                                  AND nvl(p.val_parametro, 'N') = 'S')
                               AND EXISTS (select 1
                                         from ge_cta_dat_adicionales a
                                        where a.parametro in ('PRE_RRR_CTA_MBT','PRE_RRR_CTA_MBT1','PRE_RRR_CTA_MBT2')
                                          and a.nro_cuenta = s.nro_cuenta)
                               AND NOT EXISTS (SELECT 1 -- todos los miembros tienen solo ope de ME.
                                       FROM ge_cla_operaciones xx
                                      WHERE xx.cod_persona = s.cod_persona
                                         AND xx.nro_cuenta <> s.nro_cuenta
                                         AND 'N' = (SELECT nvl(max(pp.val_parametro), 'N')
                                                    FROM ge_par_dinamicos pp
                                                   WHERE pp.parametro IN ('PRE_MAD_EXC_PYMES', 'PRE_MAD_EXCEPCION')
                                                     AND pp.cod_modalidad = xx.cod_modalidad
                                                     AND pp.cod_modulo = xx.cod_modulo)))
                    ) ;

         insert into ge_cla_operaciones_his_tmp(cat_automatica, cod_persona, fecha)
            select cat_automatica, cod_persona, fecha
            from ge_cla_operaciones_his o
            where  o.fecha = v_fec_ant_categoria
            and exists (select 1 from ge_cla_operaciones_cla_tmp cla
                        where cla.cod_persona = o.cod_persona
                        and cla.nro_cuenta = o.nro_cuenta);

     END;

   PROCEDURE pr_crc_gen_clasif(p_tip_proceso IN VARCHAR2) IS
      CURSOR c_clasifica IS
      --- Datos mensuales
    select distinct a.cod_persona
           from gv_cla_operaciones a
          where p_tip_proceso = 'M'
            and not exists (select 1 from ba_cod_referencias where dominio = 'COD_MAD_FIDEICOMISO' and val_minimo = a.cod_modalidad)
         union
         --- Datos Diarios, por operaciones registradas en CRC con nro_cuenta
          select distinct a.cod_persona
           from gv_cla_operaciones a, sb_crc_operaciones_det b
          where a.nro_cuenta = b.nro_operacion--pae_uti.fu_obt_valor(fus_obt_cta_operacion(b.nro_operacion,b.cod_modulo),1)
            and p_tip_proceso = 'D' --- las personas que tienen operaciones registradas en el dia
            and b.fecha = v_fec_fin
            and a.cod_modulo = 5
            and not exists (select 1 from ba_cod_referencias where dominio = 'COD_MAD_FIDEICOMISO' and val_minimo = a.cod_modalidad)--fieldesk-8677
        union
        --- Datos Diarios, por operaciones registradas en CRC con nro_plastico
        select distinct a.cod_persona
           from gv_cla_operaciones a, sb_crc_operaciones_det b,ta_tarjetas t
          where t.nro_cuenta = a.nro_cuenta
            and t.nro_tarjeta = b.nro_operacion--pae_uti.fu_obt_valor(fus_obt_cta_operacion(b.nro_operacion,b.cod_modulo),1)
            and p_tip_proceso = 'D' --- las personas que tienen operaciones registradas en el dia
            and b.fecha = v_fec_fin
            and a.cod_modulo = 5
            and not exists (select 1 from ba_cod_referencias where dominio = 'COD_MAD_FIDEICOMISO' and val_minimo = a.cod_modalidad)--fieldesk-8677
        union
        --- Datos Diarios, por operaciones registradas en el dia distintos al modulo 5
        select distinct a.cod_persona
           from gv_cla_operaciones a, sb_crc_operaciones_det b
          where a.nro_cuenta = pae_uti.fu_obt_valor(b.nro_operacion,1)
            and p_tip_proceso = 'D' --- las personas que tienen operaciones registradas en el dia
            and b.fecha = v_fec_fin
            and a.cod_modulo <> 5
            and not exists (select 1 from ba_cod_referencias where dominio = 'COD_MAD_FIDEICOMISO' and val_minimo = a.cod_modalidad)--fieldesk-8677
         UNION
         --- Libradores de cheques, por operaciones registradas en el dia
         SELECT DISTINCT b.cod_persona
           FROM sb_crc_vinculos_det b
          WHERE tip_vinculo = 6
            AND p_tip_proceso = 'D' --- Las personas que tienen operaciones registradas en el dia
            AND b.fecha = v_fec_fin
            AND NOT EXISTS (SELECT 1
                    FROM ge_cta_clientes s
                   WHERE s.cod_persona = b.cod_persona
                     AND s.relacion = 'P'
                     AND s.nro_cuenta = pae_uti.fu_obt_valor(b.nro_operacion, 1)) --FIELDESK-13629)
         UNION
         --- Datos Diarios, por cambio de clasificacion
         /*SELECT DISTINCT b.cod_persona
           FROM ge_clientes_nov b
          WHERE b.fec_cam_clasificacion = v_fec_fin
            AND p_tip_proceso = 'D'*/--fieldesk-8677
            --excluir persona que solo tienen operaciones tipo fideicomiso
         /*SELECT DISTINCT b.cod_persona
           FROM ge_clientes_nov b
          WHERE b.fec_cam_clasificacion = v_fec_fin--'9/12/2021' --v_fec_fin
            AND p_tip_proceso = 'D'

            and exists (select 1
                   from ge_cta_clientes cl, ge_cuentas c
                  where cl.cod_persona = b.cod_persona
                    and c.nro_cuenta = cl.nro_cuenta
                    and c.estado <> 'N'
                    and cl.relacion = 'P'
                    and c.cod_modalidad not in (690,152))   */
         SELECT DISTINCT b.cod_persona
           FROM ge_clientes_nov b
          WHERE b.fec_cam_clasificacion = v_fec_fin
            AND p_tip_proceso = 'D'
            and exists (select 1
                   from ge_cta_clientes cl, ge_cuentas c
                  where cl.cod_persona = b.cod_persona
                    and c.nro_cuenta = cl.nro_cuenta
                    and ((c.estado <> 'N' and c.cod_modulo <> 5) or (c.estado <> 'C' and c.cod_modulo in (4,5,15)))-- or (c.estado = 'N' and exists (select 1 from ge_cla_operaciones o where o.nro_cuenta = c.nro_cuenta)))
                    and cl.relacion = 'P'
                    and not exists (select 1 from ba_cod_referencias where dominio = 'COD_MAD_FIDEICOMISO' and val_minimo = c.cod_modalidad)--exclusion de fideicomiso
                    and c.cod_modulo in (4,5,6,15)
                    union all
                    select 1 --cancelaciones del dia para mejora de categoria
                    from PR_CTA_PRESTAMOS p, ge_cla_operaciones o
                    where o.nro_cuenta = p.nro_cuenta
                    and o.cod_persona = b.cod_persona
                    and p.estado = 'N'
                    and p.fec_cancelacion = v_fec_fin)
		 UNION
         --- Datos Diarios: clientes que salieron de la cartera activa respecto
         --- del dia habil anterior y cuya categoria informada quedo
         --- desactualizada. FIELDESK-157375 (a)
         SELECT g.cod_persona
           FROM ge_clientes g
          WHERE p_tip_proceso = 'D'
            AND TO_NUMBER(REGEXP_SUBSTR(
                   (SELECT MAX(d2.cat_riesgo) KEEP (DENSE_RANK LAST ORDER BY d2.fecha)
                      FROM sb_crc_clasificaciones_det d2
                     WHERE d2.cod_persona = g.cod_persona
                       AND d2.nom_referencia = 'CLASIFICA'), '^[0-9]'))
                != TRUNC(g.cat_automatica)
            AND EXISTS (SELECT 1
                          FROM ge_cla_operaciones_his h
                         WHERE h.cod_persona = g.cod_persona
                           AND h.fecha = v_fec_ant_categoria
                           AND (nvl(h.tot_deu_real,0) <> 0
                             OR nvl(h.tot_deu_contingente,0) <> 0))
            AND NOT EXISTS (SELECT 1
                              FROM ge_cla_operaciones o
                             WHERE o.cod_persona = g.cod_persona
                               AND (nvl(o.tot_deu_real,0) <> 0
                                 OR nvl(o.tot_deu_contingente,0) <> 0)) 
         UNION
          -- Conyuges
        SELECT DISTINCT e.cod_persona
          FROM sb_crc_vinculos_det e, ba_personas b, ge_cuentas o
         WHERE tip_vinculo IN (002, 004, 005, 006, 007, 010)
           AND e.cod_modulo <> 3
           AND b.cod_persona = e.cod_persona
           and o.nro_cuenta = pae_uti.fu_obt_valor(e.nro_operacion, 1)
           and not exists (select 1 from ba_cod_referencias where dominio = 'COD_MAD_FIDEICOMISO' and val_minimo = o.cod_modalidad)
           AND NOT EXISTS (SELECT 1 -->se excluyen operaciones de vta de cartera
                             FROM sb_crc_vta_carteras v --FIELDESK-34615
                              where (v.nro_cuenta_bt = e.nro_operacion or v.nro_cuenta = e.nro_operacion)
                              and v.estado_vta_cartera='C')
           AND ((p_tip_proceso = 'M') OR
               (p_tip_proceso = 'D' AND EXISTS
                (SELECT 1
                    FROM sb_crc_operaciones_det t, ge_cta_clientes m, sb_crc_vinculos_det f
                   WHERE t.nro_operacion = e.nro_operacion
                     AND m.nro_cuenta = pae_uti.fu_obt_valor(t.nro_operacion, 1)
                     AND m.nro_cuenta = pae_uti.fu_obt_valor(e.nro_operacion, 1)
                     and f.nro_operacion= t.nro_operacion
                     and f.tip_vinculo ='001'
                     and m.cod_persona= f.cod_persona
                     AND m.relacion = 'P'
                     AND t.fecha = v_fec_fin)))
         UNION
         -- Cuentas Bancarias
         SELECT DISTINCT c.cod_persona
           FROM ge_clientes d, ge_cta_clientes b, cc_cta_bancarias a, ge_bancos c
          WHERE a.nro_cuenta = b.nro_cuenta
            AND b.cod_persona = d.cod_persona
            AND a.cod_modalidad = 43
            AND a.est_batch NOT IN ('C', 'X')
            AND relacion = 'P'
            AND nvl(sal_tot_batch, 0) - nvl(sal_ret_batch, 0) <> 0
            AND a.cod_banco = c.cod_banco
            AND c.cod_persona <> v_cod_per_bco_central
            AND v_inc_cta_bancarias = 'S'
            AND p_tip_proceso = 'M';
/*          UNION -->se excluyen operaciones de vta de cartera
         SELECT distinct (v.cod_persona)
           FROM pr_vta_carteras v
          WHERE (v_fec_fin - v.fec_ope_ente) <= v_crc_can_dia_incobrable
            AND p_tip_proceso = 'M';*/
     V_USER  sb_log_crc.usu_insercion%type;
     TYPE    cursor2_type      IS TABLE OF c_clasifica%rowtype;
     reg2    cursor2_type;
     reg_slcrc rp_slcrc_type := rp_slcrc_type();

      CURSOR c_conyuge IS
        with clasifica as(
            select a.nro_documento, a.cod_persona, nvl(a.mto_riesgo,0)mto_riesgo, nvl(a.tot_garantia,0)tot_garantia, a.nro_registro, nvl(a.mto_rie_contingente,0)mto_rie_contingente, 0 as mto_rie_codeudor
              FROM sb_crc_clasificaciones_det a
              WHERE a.fecha = v_fec_fin
            ),--crc_co
        conyugue_v as(
         select s.cod_persona, s.descripcion, pae_uti.fu_obt_valor(t.nro_operacion, 1) nro_operacion, t.NRO_DOCUMENTO
            from  ge_entes s join sb_crc_vinculos_det t on ( s.cod_persona = t.cod_persona)
           where t.tip_vinculo IN (10)
             AND s.tipo = 'CC'
        ),
        CTA_DAT_CTA_PREST AS (
            SELECT b.val_parametro, o.cod_moneda, nvl(o.sal_cap_batch,0)sal_cap_batch, nvl(o.dev_no_cobrado,0)dev_no_cobrado, o.nro_cuenta
              FROM ge_cta_dat_adicionales b
              JOIN pr_cta_prestamos o ON (o.nro_cuenta = b.nro_cuenta)
             WHERE b.parametro in ('PRE_COD_ENT_COM_CARTERA', 'PRE_COM_RECURSO')
               AND b.val_parametro = 'S'
               AND o.cod_modulo = 6
               and o.estado <>'N'
               and not exists (select 1 from ba_cod_referencias where dominio = 'COD_MAD_FIDEICOMISO' and val_minimo = o.cod_modalidad)
        )
      select b.cod_persona, nvl(b.mto_rie_codeudor,0)mto_rie_codeudor, nvl(b.tot_garantia,0)tot_garantia, b.nro_registro, nvl(b.mto_rie_contingente,0)mto_rie_contingente, b.nro_documento,
                (SELECT CASE
                                 WHEN COUNT(DISTINCT a.cod_persona) = 1 THEN MAX(a.cod_persona)
                            END
                     FROM it.ge_cta_clientes a, it.ge_cuentas c
                   WHERE a.relacion NOT IN ('P', 'A', 'D')
                      AND a.cod_persona = b.cod_persona
                      AND a.nro_cuenta = c.nro_cuenta
                      AND c.estado <> 'N') COD_CODEUDOR
      from (
        SELECT SUM(nvl(pag_gen.fu_con_mon_a_moneda(o.cod_moneda, pag_gen.fu_obt_mon_local,
                       nvl(o.sal_cap_batch,0) + nvl(o.dev_no_cobrado,0), NULL), 0)) mto_rie_codeudor,  -- SE AJUSTA EL CALCULO DE COMPRA DE CARTERA --FIELDESK-34615
                       c.cod_persona,
                       nvl(c.mto_riesgo,0)mto_riesgo, nvl(c.tot_garantia,0)tot_garantia, c.nro_registro, nvl(c.mto_rie_contingente,0)mto_rie_contingente, c.nro_documento
         from conyugue_v s,
              clasifica c,
              CTA_DAT_CTA_PREST o
        where c.cod_persona = s.cod_persona
          and s.nro_operacion = o.nro_cuenta
          and s.descripcion = o.val_parametro
          group by c.cod_persona, c.mto_riesgo, c.tot_garantia, c.nro_registro, c.mto_rie_contingente, c.nro_documento
        union all
        SELECT SUM(nvl(a.sal_capital, 0) + nvl(a.sal_int_dev_no_cobrado, 0) ) sal_capital,
                    b.cod_persona,
                    nvl(b.mto_riesgo,0), nvl(b.tot_garantia,0), b.nro_registro, nvl(b.mto_rie_contingente,0), b.nro_documento
          FROM it.sb_crc_saldos_det a,
                   (SELECT c.tip_operacion, c.nro_operacion, nvl(c.cod_persona, a.cod_persona) cod_persona, nvl(a.mto_riesgo,0)mto_riesgo, nvl(a.tot_garantia,0)tot_garantia, a.nro_registro, nvl(a.mto_rie_contingente,0)mto_rie_contingente, a.nro_documento
                      FROM sb_crc_vinculos_det c join  clasifica a on (c.nro_documento = a.nro_documento)
                     WHERE c.tip_vinculo IN (002, 004, 005, 006, 007, 010)
                       AND c.cod_modulo <> 3) b
          WHERE a.fecha = v_fec_fin
            AND a.nro_operacion = b.nro_operacion
            and a.tip_operacion = b.tip_operacion
            and a.nom_referencia not in('SALDOSF','SALDOSAF')
            AND nvl(a.cod_modulo,1) <> 3--para obtener codeudores de migracion vta cartera--FIELDESK-34615
            AND NOT EXISTS (SELECT 1 -- Se excluyen operaciones de vta de cartera
                             FROM sb_crc_vta_carteras v
                              where (v.nro_cuenta_bt = a.nro_operacion or v.nro_cuenta = a.nro_operacion)
                              and v.estado_vta_cartera='C')
          GROUP BY b.cod_persona, b.mto_riesgo, b.tot_garantia, b.nro_registro, b.mto_rie_contingente, b.nro_documento
          union
          SELECT nvl(o.sal_capital,0), o.cod_persona, nvl(c.mto_riesgo,0), nvl(c.tot_garantia,0), c.nro_registro, nvl(c.mto_rie_contingente,0), c.nro_documento
              FROM sv_crc_mon_codeudor o, clasifica c
              WHERE o.fecha =  v_fec_fin
              AND o.cod_persona = c.cod_persona) b;

      rp_slcrc              sb_log_crc%ROWTYPE;
      rp_sccla              sb_crc_clasificaciones_det%ROWTYPE;
      v_tot_prevision       ge_cla_operaciones.tot_prevision%TYPE;
      v_mto_rie_codeudor    sb_crc_clasificaciones_det.mto_riesgo%TYPE;
      v_tot_rie_documento   sb_crc_clasificaciones_det.mto_riesgo%TYPE;
      v_tot_riesgo          sb_crc_clasificaciones_det.mto_riesgo%TYPE;
      v_mto_rie_contingente sb_crc_clasificaciones_det.mto_riesgo%TYPE;
      v_mto_sobregiro       cc_cta_corrientes.sal_total%TYPE;
      v_cat_riesgo          ge_cla_operaciones.cat_automatica%TYPE;
      v_cat_final           ba_cod_referencias.significado%type;
      v_tip_documento       sb_crc_vinculos_det.tip_documento%TYPE;
      v_nro_documento       sb_crc_vinculos_det.nro_documento%TYPE;
      v_fec_nacimiento      sb_crc_vinculos_det.fec_nacimiento%TYPE;
      v_nombres             sb_crc_vinculos_det.nombres%TYPE;
      v_apellidos           sb_crc_vinculos_det.apellidos%TYPE;
      v_cod_conyuge         ba_personas.cod_persona%TYPE;
      v_cod_codeudor        ba_personas.cod_persona%TYPE;
      v_sal_cta_bancaria    cc_cta_bancarias.sal_total%TYPE;
      v_nro_registro        sb_crc_operaciones.tot_registro%TYPE := 0;
      v_ind_cta_bancaria    VARCHAR2(1) := 'N';
      v_fec_ini_vta         date := pag_cal.g_pri_dia_mes;
      v_fec_fin_vta         date := pag_cal.g_ult_dia_mes;
      v_ope_activa          varchar2(1);
      TYPE type_rp_sccla     IS TABLE OF sb_crc_clasificaciones_det%ROWTYPE;
      reg_type_rp_sccla      type_rp_sccla not null:= type_rp_sccla();
      TYPE type_conyuge      IS TABLE OF c_conyuge%rowtype;
      reg_conyuge            type_conyuge not null := type_conyuge();
      v_cuo_incobrables      number;
      v_cuo_ven_incobrables  number;
      v_md_doc_incobrables   number;
      v_exi_incobrables      varchar2(1):='N';

      -- Procedimiento de generacion de Archivo de Clasificaciones Sobrecargado para insertar en BULK
   PROCEDURE lp_ins_crc_clasificaciones(reg_type_rp_sccla IN type_rp_sccla) IS
   l_error_count number;
   BEGIN

   FORALL i IN 1 .. reg_type_rp_sccla.count SAVE EXCEPTIONS
     INSERT INTO sb_crc_clasificaciones_det
         (fecha,
          nom_referencia,
          nro_formulario,
          nro_registro,
          tip_documento,
          nro_documento,
          fec_nacimiento,
          nombres,
          apellidos,
          cat_riesgo,
          cat_subjetiva,
          cat_rie_fideicomiso,
          por_prevision,
          mto_rie_contingente,
          mto_riesgo,
          sal_cap_vencido,
          sal_int_vencido,
          tot_garantia,
          tot_cap_pri_prevision,
          tot_cap_seg_prevision,
          tot_int_pri_prevision,
          tot_int_seg_prevision,
          tot_tc,
          tot_dc,
          tot_tr,
          tot_dr,
          tot_er,
          tot_sr,
          cod_persona,
          mto_vta_cartera,
          mto_deu_incobrable,
      por_ing_mon_extranjera
          )
      VALUES
         (reg_type_rp_sccla(i).fecha,
          reg_type_rp_sccla(i).nom_referencia,
          reg_type_rp_sccla(i).nro_formulario,
          reg_type_rp_sccla(i).nro_registro,
          reg_type_rp_sccla(i).tip_documento,
          reg_type_rp_sccla(i).nro_documento,
          reg_type_rp_sccla(i).fec_nacimiento,
          reg_type_rp_sccla(i).nombres,
          reg_type_rp_sccla(i).apellidos,
          reg_type_rp_sccla(i).cat_riesgo,
          reg_type_rp_sccla(i).cat_subjetiva,
          reg_type_rp_sccla(i).cat_rie_fideicomiso,
          reg_type_rp_sccla(i).por_prevision,
          reg_type_rp_sccla(i).mto_rie_contingente,
          reg_type_rp_sccla(i).mto_riesgo,
          reg_type_rp_sccla(i).sal_cap_vencido,
          reg_type_rp_sccla(i).sal_int_vencido,
          reg_type_rp_sccla(i).tot_garantia,
          reg_type_rp_sccla(i).tot_cap_pri_prevision,
          reg_type_rp_sccla(i).tot_cap_seg_prevision,
          reg_type_rp_sccla(i).tot_int_pri_prevision,
          reg_type_rp_sccla(i).tot_int_seg_prevision,
          reg_type_rp_sccla(i).tot_tc,
          reg_type_rp_sccla(i).tot_dc,
          reg_type_rp_sccla(i).tot_tr,
          reg_type_rp_sccla(i).tot_dr,
          reg_type_rp_sccla(i).tot_er,
          reg_type_rp_sccla(i).tot_sr,
          reg_type_rp_sccla(i).cod_persona,
          reg_type_rp_sccla(i).mto_vta_cartera,
          reg_type_rp_sccla(i).mto_deu_incobrable,
      reg_type_rp_sccla(i).por_ing_mon_extranjera);

        EXCEPTION WHEN OTHERS THEN
          l_error_count := SQL%BULK_EXCEPTIONS.count;
        FOR indx IN 1 .. SQL%BULK_EXCEPTIONS.COUNT  LOOP
             RAISE_APPLICATION_ERROR(-20000, 'ERROR insertando en sb_crc_clasificaciones_det en lp_ins_crc_clasificaciones! ' ||  SQLERRM(-SQL%BULK_EXCEPTIONS(indx).ERROR_CODE));
        END LOOP;
     END;

      PROCEDURE lp_crc_gen_dat_clasifica(p_tip_periodo IN VARCHAR2 DEFAULT 'D') IS
      BEGIN
         pag_cal.pr_obt_dat_calendar(1);
         v_fec_actual        :=  pag_cal.fu_obt_fec_actual(1);
         v_fec_inicio        :=  pag_cal.fu_obt_fec_actual(1);
         v_fec_fin           :=  pag_cal.fu_obt_fec_actual(1);
         v_fec_ant_categoria :=  pag_cal.g_fec_anterior;

         IF p_tip_periodo = 'M' THEN
            v_fec_inicio := pag_cal.g_pri_dia_mes;
            v_fec_fin    := pag_cal.g_ult_dia_mes;
         END IF;
         DELETE sb_crc_clasificaciones_det
          WHERE fecha = v_fec_fin;
         DELETE sb_crc_clasificaciones
          WHERE fec_periodo = v_fec_fin;
         DELETE ge_clientes_nov
          WHERE fec_cam_clasificacion = v_fec_fin;
         DELETE sb_log_crc
          WHERE nom_referencia = 'CLASIFICA'
            AND fecha = v_fec_fin;
         COMMIT;
      END;

      PROCEDURE lp_act_cat_riesgo IS
         CURSOR c_clientes IS
            SELECT a.cat_riesgo cat_actual, b.CAT_RIESGO cat_anterior, a.cod_persona, null as cat_rie_ant, null as cat_riesgo, NULL as cat_ope_his , NULL as cat_ope
                 FROM ge_clientes a, IT.ge_clientes_his b --ge_clientes_his b
                where a.cod_persona = b.cod_persona
                  and b.fecha = v_fec_ant_categoria
                  and a.cat_riesgo != b.CAT_RIESGO;

         CURSOR c_operaciones IS
            select a.cat_actual, a.cod_persona, b.cat_anterior
               from (SELECT MAX(c.cat_automatica) cat_actual, c.cod_persona
                       FROM ge_cla_operaciones_cla_tmp c
                      WHERE c.cat_automatica >= 1
                        AND c.cat_automatica < 2
                      GROUP BY c.cod_persona) a,
                    (SELECT MAX(g.cat_automatica) cat_anterior, g.cod_persona
                       FROM ge_cla_operaciones_his_tmp g
                      WHERE g.cat_automatica >= 1
                        AND g.cat_automatica < 2
                        AND g.fecha = v_fec_ant_categoria
                      GROUP BY g.cod_persona) b,
                    ge_clientes z
              where a.cod_persona = b.cod_persona
                and a.cat_actual != b.cat_anterior
                and a.cod_persona = z.cod_persona
                and z.cat_riesgo = 1
                and z.cat_riesgo = (SELECT cat_riesgo
                                       FROM IT.ge_clientes_his b
                                      WHERE cod_persona = a.cod_persona
                                        AND fecha = v_fec_ant_categoria);

         v_cat_rie_act_final ge_cla_operaciones.cat_automatica%TYPE;
         v_cat_rie_ant_final ge_cla_operaciones.cat_automatica%TYPE;
         v_cat_ope_his       ge_cla_operaciones.cat_automatica%TYPE;
         v_cat_ope           ge_cla_operaciones.cat_automatica%TYPE;
         v_cat_resultante    ge_cla_operaciones.cat_automatica%TYPE;
         v_cat_riesgo        ba_cod_referencias.significado%TYPE; ---Categoria de Riesgo convertida 1a o 1b
         v_cat_rie_ant       ba_cod_referencias.significado%TYPE; ---Categoria Anterior convertida 1a o 1b
         l_error_count       number;
         TYPE      cursor1_type IS TABLE OF c_clientes%ROWTYPE;
         reg1      cursor1_type;
         TYPE      cursorOp_type IS TABLE OF c_operaciones%ROWTYPE;
         regOp     cursorOp_type := cursorOp_type();
         recCliNov cursorCliOp_type := cursorCliOp_type();

      BEGIN

        ---carga de tablas temporales
        lp_crc_cla_ins_tmp(v_fec_ant_categoria);

         --- --fieldesk 14515
         v_cat_rie_act_final := NULL;
         v_cat_rie_ant_final := NULL;
         v_cat_riesgo        := NULL;
         v_cat_rie_ant       := NULL;

          SELECT a.cat_riesgo cat_actual, b.CAT_RIESGO cat_anterior, a.cod_persona, null as cat_rie_ant, null as cat_riesgo, NULL as cat_ope_his , NULL as cat_ope
          BULK COLLECT INTO reg1
          FROM ge_clientes a, IT.ge_clientes_his b
          where a.cod_persona = b.cod_persona
          and b.fecha = v_fec_ant_categoria
          and a.cat_riesgo != b.CAT_RIESGO;

            FOR i IN 1 .. reg1.count LOOP

            BEGIN
               SELECT MAX(b.cat_automatica) cat_his
                 INTO v_cat_ope_his
                 FROM ge_cla_operaciones_his b
                WHERE b.fecha = v_fec_ant_categoria
                  AND b.cod_persona = reg1(i).cod_persona
                GROUP BY b.cod_persona;
            EXCEPTION
               WHEN OTHERS THEN
                  v_cat_ope_his := NULL;
            END;
            BEGIN
               SELECT MAX(a.cat_automatica) cat_act
                 INTO v_cat_ope
                 FROM ge_cla_operaciones a
                WHERE a.cod_persona = reg1(i).cod_persona
                GROUP BY a.cod_persona;
            EXCEPTION
               WHEN OTHERS THEN
                  v_cat_ope := NULL;
            END;
            v_cat_rie_act_final := reg1(i).cat_actual;
            v_cat_rie_ant_final := reg1(i).cat_anterior;
            IF v_cat_rie_act_final = 1 THEN
               IF v_cat_ope_his <> v_cat_ope THEN
                  v_cat_rie_act_final := v_cat_ope;
                  v_cat_rie_ant_final := v_cat_ope_his;
               END IF;
            END IF;
            v_cat_riesgo  := fue_obt_des_refcodes('CAT_RIE_BCP', REPLACE(v_cat_rie_act_final, ',', '.'));
            v_cat_rie_ant := fue_obt_des_refcodes('CAT_RIE_BCP', REPLACE(v_cat_rie_ant_final, ',', '.'));

            IF upper(v_cat_riesgo) like upper('%Referencia%Sistema%') THEN
               v_cat_riesgo := fue_obt_des_refcodes('CAT_RIE_BCP', REPLACE(v_cat_rie_act_final, '.', ','));
            END IF;
            IF upper(v_cat_rie_ant) like upper('%Referencia%Sistema%') THEN
               v_cat_rie_ant := fue_obt_des_refcodes('CAT_RIE_BCP', REPLACE(v_cat_rie_ant_final, '.', ','));
            END IF;

            recCliNov.EXTEND(1);
            recCliNov(recCliNov.LAST).cod_persona:=reg1(i).cod_persona;
            recCliNov(recCliNov.LAST).fec_cam_clasificacion:=v_fec_fin;
            recCliNov(recCliNov.LAST).cat_rie_anterior:=v_cat_rie_ant;
            recCliNov(recCliNov.LAST).cat_rie_actual:=v_cat_riesgo;

            v_cat_rie_act_final := NULL;
            v_cat_rie_ant_final := NULL;
            v_cat_rie_ant       := NULL;
            v_cat_riesgo        := NULL;
         END LOOP;

         lp_ins_clientes_nov (recCliNov); --> Inserta ge_clientes_nov en bulk

         recCliNov:= cursorCliOp_type();

         OPEN c_operaciones;
         LOOP FETCH c_operaciones BULK COLLECT INTO regOp ;
            FOR z IN 1 .. regOp.count LOOP

               IF regOp(z).cat_anterior <> regOp(z).cat_actual THEN
                  v_cat_rie_act_final := regOp(z).cat_actual;
                  v_cat_rie_ant_final := regOp(z).cat_anterior;
               END IF;

               v_cat_riesgo  := fue_obt_des_refcodes('CAT_RIE_BCP', REPLACE(v_cat_rie_act_final, ',', '.'));
               v_cat_rie_ant := fue_obt_des_refcodes('CAT_RIE_BCP', REPLACE(v_cat_rie_ant_final, ',', '.'));

               IF upper(v_cat_riesgo) like upper('%Referencia%Sistema%') THEN
                  v_cat_riesgo := fue_obt_des_refcodes('CAT_RIE_BCP', REPLACE(v_cat_rie_act_final, '.', ','));
               END IF;
               IF upper(v_cat_rie_ant) like upper('%Referencia%Sistema%') THEN
                  v_cat_rie_ant := fue_obt_des_refcodes('CAT_RIE_BCP', REPLACE(v_cat_rie_ant_final, '.', ','));
               END IF;

              recCliNov.EXTEND(1);
              recCliNov(recCliNov.LAST).cod_persona:=regOp(z).cod_persona;
              recCliNov(recCliNov.LAST).fec_cam_clasificacion:=v_fec_fin;
              recCliNov(recCliNov.LAST).cat_rie_anterior:=v_cat_rie_ant;
              recCliNov(recCliNov.LAST).cat_rie_actual:=v_cat_riesgo;

              v_cat_rie_act_final := NULL;
              v_cat_rie_ant_final := NULL;
              v_cat_rie_ant       := NULL;
              v_cat_riesgo        := NULL;

         END LOOP;
         EXIT WHEN c_operaciones%NOTFOUND;
          END LOOP;
         CLOSE c_operaciones;

         lp_ins_clientes_nov (recCliNov); --> Inserta ge_clientes_nov en bulk
      END;

   BEGIN
      lp_crc_gen_dat_clasifica(p_tip_proceso);
      SELECT substr(USER, 1, 10) INTO V_USER FROM DUAL;

        begin
            select count(1) into v_cuo_incobrables from pr_cuotas where estado = 'I';
            IF v_cuo_incobrables = 0 then
                select count(1) into v_cuo_ven_incobrables from ov_cta_vencidas where estado = 'I';
                if v_cuo_ven_incobrables = 0 then
                    select count(1) into v_md_doc_incobrables from md_doc_detalles where estado = 'I';
                else
                    v_exi_incobrables :='S';
                end if;
            else
               v_exi_incobrables :='S';
            end if;

            if v_md_doc_incobrables >0 then
                v_exi_incobrables :='S';
            end if;
         exception
           when no_Data_found then
             v_cuo_incobrables := 0;
             v_cuo_ven_incobrables := 0;
             v_md_doc_incobrables := 0;
         end;

      IF p_tip_proceso = 'D' then
         --- Ejecutar solo si es Clasifica Diario
         lp_act_cat_riesgo;
      END IF;

      IF c_clasifica%ISOPEN THEN
      CLOSE c_clasifica;
       END IF;

      OPEN c_clasifica;
        LOOP
        FETCH c_clasifica BULK COLLECT INTO reg2 ;

        FOR i IN 1 .. reg2.count LOOP
         v_mensaje               := NULL;
         rp_sccla.fecha          := v_fec_fin; -- Fecha
         rp_sccla.nom_referencia := 'CLASIFICA'; -- Nombre Rerencia Archivo
         rp_sccla.nro_formulario := '011'; -- Formulario (011)
         rp_sccla.cod_persona    := reg2(i).cod_persona;
         lp_obt_dat_persona(reg2(i).cod_persona, v_tip_documento, v_nro_documento, v_fec_nacimiento, v_nombres, v_apellidos);
         IF v_tip_documento IS NOT NULL THEN
            rp_sccla.tip_documento := v_tip_documento; -- Tipo de Documento (CI=Cedula de Identidad / CRC=Codigo de Persona no residente / CRP=Carne de Residencia Permanente / RUC=Regsitro Unico Contribuyente)
         ELSE
            rp_sccla.tip_documento := NULL;
            v_mensaje              := v_mensaje || ', Tipo Documento es nulo';
         END IF;
         IF v_nro_documento IS NOT NULL THEN
            rp_sccla.nro_documento := v_nro_documento; -- Numero de Documento de Identidad
         ELSE
            rp_sccla.nro_documento := NULL;
            v_mensaje              := v_mensaje || ', Numero de Documento es nulo';
         END IF;
         IF v_fec_nacimiento IS NOT NULL THEN
            rp_sccla.fec_nacimiento := v_fec_nacimiento; -- Fecha de nacimiento AAAAMMDD
         ELSE
            rp_sccla.fec_nacimiento := NULL;
            v_mensaje               := v_mensaje || ', Fecha de Nacimiento es nulo';
         END IF;
         IF v_nombres IS NOT NULL THEN
            rp_sccla.nombres := v_nombres; -- Nombres
         ELSE
            rp_sccla.nombres := NULL;
            v_mensaje        := v_mensaje || ', Nombres es nulo';
         END IF;
         IF v_apellidos IS NOT NULL THEN
            rp_sccla.apellidos := v_apellidos; -- Apellidos
         ELSE
            rp_sccla.apellidos := NULL;
            v_mensaje          := v_mensaje || ', Apellidos es nulo';
         END IF;
         lp_obt_dat_cta_bancarias(reg2(i).cod_persona, v_sal_cta_bancaria, v_ind_cta_bancaria);
         lp_obt_mto_vta_cartera (rp_sccla.nro_documento ,
                                 rp_sccla.mto_vta_cartera); --- obtener vta de cartera

         ---- Obtener la Clasificacion de Riesgo de la Persona
         v_cat_riesgo := fus_obt_cat_riesgo(reg2(i).cod_persona);

         --verifica si el cliente posee operaciones activas --fieldesk-14837
         begin
           select distinct 'S'
           into v_ope_activa
           from ge_cla_operaciones c
           where c.cod_persona = reg2(i).cod_persona;
         exception
           when no_Data_found then
             v_ope_activa := 'N';
           when others then
             v_ope_activa := 'N';
         end;
         --Para casos de venta de cartera de clientes sin deuda en la entidad.--fieldesk-14837
         IF nvl(rp_sccla.mto_vta_cartera, 0) > 0 AND v_cat_riesgo = 1 and v_ope_activa = 'N' THEN
            v_cat_riesgo := lf_obt_cat_vta_cartera(reg2(i).cod_persona);
         END IF;
         ---- Si la Cat. es 1 verifica si tiene operaciones con mora Cat. 1a o 1b (Res. 37)
         IF v_cat_riesgo = 1 THEN
            v_cat_riesgo := lf_obt_cat_prevision(reg2(i).cod_persona,p_tip_proceso);
            v_cat_riesgo := (CASE
                               WHEN v_cat_riesgo = 1.1 THEN
                                1.1
                               WHEN v_cat_riesgo > 1.1 THEN
                                1.2
                               ELSE
                                1
                            END);
         END IF;
         IF v_ind_cta_bancaria = 'S' THEN
            v_cat_riesgo := 1;
         END IF;
         IF v_cat_riesgo IS NULL THEN
            v_cat_riesgo := 1; -- para libradores que no son clientes.
         END IF;
         -- recuperar si el mto es o no de venta de cartera
         v_cat_final := fue_obt_des_refcodes('CAT_RIE_BCP', REPLACE(nvl(v_cat_riesgo, 1), ',', '.'));

         IF upper(v_cat_final) like upper('%Referencia%Sistema%') THEN
            v_cat_final := fue_obt_des_refcodes('CAT_RIE_BCP', REPLACE(nvl(v_cat_riesgo, 1), '.', ','));
         END IF;

         rp_sccla.cat_riesgo := v_cat_final;

         rp_sccla.por_prevision := fus_obt_por_prevision(v_cat_riesgo); --- Porcentaje de Prevision a partir de la Categoria de Riesgo
         rp_sccla.cat_subjetiva := fus_obt_cat_subjetiva(reg2(i).cod_persona); -- Calificacion Subjetiva ANEXO Clasificacion de Riesgo
         rp_sccla.cat_rie_fideicomiso    := NULL; --- Calificacion Subjetiva ANEXO Clasificacion de Riesgo
         lp_obt_dat_cla_persona(reg2(i).cod_persona,
                                rp_sccla.mto_riesgo,
                                v_tot_prevision,
                                v_mto_rie_contingente,
                                rp_sccla.tot_garantia,
                                --- Saldo Garantia para Previsiones
                                rp_sccla.tot_cap_pri_prevision,
                                --- Saldo 1ra Prevision capital
                                rp_sccla.tot_int_pri_prevision,
                                --- Saldo 2da Prevision capital
                                rp_sccla.tot_cap_seg_prevision,
                                --- Saldo 1ra Prevision interes
                                rp_sccla.tot_int_seg_prevision); --- Saldo 2da Prevision interes
         rp_sccla.mto_rie_contingente := v_mto_rie_contingente; --- Saldo/Monto Riesgo Contingente
         --- Tiene que ser por persona, y sumar
         lp_obt_dat_sobregiro(reg2(i).cod_persona, v_mto_sobregiro);
         IF rp_sccla.mto_riesgo IS NOT NULL THEN
            IF v_mto_sobregiro > 0 AND rp_sccla.mto_riesgo <> 0 THEN
               v_mensaje := v_mensaje ||
                            ', El Monto Riesgo debe ser cero. Corresponde a un sobregiro sin monto negativo.';
            END IF;
            IF rp_sccla.mto_riesgo < 0 THEN
               v_mensaje := v_mensaje || ', El Monto Riesgo es negativo';
            END IF;
         ELSE
            v_mensaje := v_mensaje || ', El Monto Riesgo es nulo o negativo';
         END IF;
         rp_sccla.tot_sr := 0; -- Saldo/Monto Riesgo para Codeudor calculado mas abajo.

         if v_exi_incobrables = 'S' THEN
             lp_obt_dat_incobrable (reg2(i).cod_persona,
                                    rp_sccla.mto_deu_incobrable);  --- obtener saldo incobrable
         END IF;
         if nvl(rp_sccla.mto_deu_incobrable, 0) = 0 then
            lp_obt_dat_cta_vencida(reg2(i).cod_persona,
                                   rp_sccla.sal_cap_vencido,
                                   --- Saldo Capital Vencido
                                   rp_sccla.sal_int_vencido); --- Saldo Interes Vencido
         end if;

         lp_obt_dat_cla_rie_total(reg2(i).cod_persona, v_tot_riesgo);
         rp_sccla.tot_tc := 0; --v_tot_riesgo; --- TC-Credito Concedido (0 para codeudor, o descuento de documentos)  ;
         lp_obt_mto_rie_documento(reg2(i).cod_persona, v_tot_rie_documento); --- DC-Credito de descuento de documentos (0 para codeudorias)
         rp_sccla.tot_dc := 0; --v_tot_rie_documento;
         rp_sccla.tot_tr := v_tot_riesgo; ---TR-Riesgo asumido por prestamo concedido (Saldo Riesgo)
         rp_sccla.tot_dr := v_tot_rie_documento; ---DR-Riesgo Asumido por descuento de documentos
         rp_sccla.tot_er := v_mto_rie_contingente; ---ER-Riesgo derivado por el descuento (solo si la persona es el emisor del dcto)
         IF v_ind_cta_bancaria = 'S' AND v_inc_cta_bancarias = 'S' THEN
            -- Si corresponde a una cta. bancaria reasignar valores
            rp_sccla.tot_tr     := rp_sccla.tot_tr + ROUND(v_sal_cta_bancaria, 0);
            rp_sccla.mto_riesgo := rp_sccla.mto_riesgo + ROUND(v_sal_cta_bancaria, 0);
            rp_sccla.tot_dr     := 0;
            rp_sccla.tot_er     := 0;
            rp_sccla.tot_sr     := 0;
         END IF;
         IF lf_obt_ope_persona(reg2(i).cod_persona, 8) = 'S' OR lf_obt_ope_persona(reg2(i).cod_persona, 4) = 'S' OR
            lf_obt_ope_persona(reg2(i).cod_persona, 5) = 'S' THEN
            IF rp_sccla.mto_rie_contingente = 0 AND rp_sccla.tot_er = 0 THEN
               v_mensaje := v_mensaje || ', MTO_CONTINGENTE y TOT_ER no pueden ser cero.';
            END IF;
         END IF;
         --IF p_tip_proceso = 'M' THEN
         --   rp_sccla.fec_nacimiento := v_fec_fin;
         --END IF;
         IF lf_obt_dat_des_documentos(reg2(i).cod_persona, 'C') = 'S' THEN
            IF rp_sccla.tot_tr = 0 THEN
               v_mensaje := v_mensaje || ', TOT_TR y TOT_TC no pueden ser cero.';
            END IF;
            IF rp_sccla.tot_dr = 0 THEN
               v_mensaje := v_mensaje || ', TOT_DR y TOT_DC no pueden ser cero.';
            END IF;
         END IF;
         IF v_tot_prevision <> (rp_sccla.tot_cap_pri_prevision + rp_sccla.tot_cap_seg_prevision +
            rp_sccla.tot_int_pri_prevision + rp_sccla.tot_int_seg_prevision) THEN
            v_mensaje := v_mensaje || ', TOTAL Prevision es incorrecto.';
         END IF;
         v_nro_registro        := v_nro_registro + 1;
         rp_sccla.nro_registro := v_nro_registro; --- Nro. de Registro
     rp_sccla.por_ing_mon_extranjera := 0; --- Porcentaje de ingresos en moneda extranjera

          reg_type_rp_sccla.EXTEND(1);
          reg_type_rp_sccla(reg_type_rp_sccla.LAST).fecha:= rp_sccla.fecha;
          reg_type_rp_sccla(reg_type_rp_sccla.LAST).nom_referencia:=rp_sccla.nom_referencia;
          reg_type_rp_sccla(reg_type_rp_sccla.LAST).nro_formulario:=rp_sccla.nro_formulario;
          reg_type_rp_sccla(reg_type_rp_sccla.LAST).nro_registro:=rp_sccla.nro_registro;
          reg_type_rp_sccla(reg_type_rp_sccla.LAST).tip_documento:=rp_sccla.tip_documento;
          reg_type_rp_sccla(reg_type_rp_sccla.LAST).nro_documento:=rp_sccla.nro_documento;
          reg_type_rp_sccla(reg_type_rp_sccla.LAST).fec_nacimiento:=rp_sccla.fec_nacimiento;
          reg_type_rp_sccla(reg_type_rp_sccla.LAST).nombres:=rp_sccla.nombres;
          reg_type_rp_sccla(reg_type_rp_sccla.LAST).apellidos:=rp_sccla.apellidos;
          reg_type_rp_sccla(reg_type_rp_sccla.LAST).cat_riesgo:=rp_sccla.cat_riesgo;
          reg_type_rp_sccla(reg_type_rp_sccla.LAST).cat_subjetiva:=rp_sccla.cat_subjetiva;
          reg_type_rp_sccla(reg_type_rp_sccla.LAST).cat_rie_fideicomiso:=rp_sccla.cat_rie_fideicomiso;
          reg_type_rp_sccla(reg_type_rp_sccla.LAST).por_prevision:=rp_sccla.por_prevision;
          reg_type_rp_sccla(reg_type_rp_sccla.LAST).mto_rie_contingente:=rp_sccla.mto_rie_contingente;
          reg_type_rp_sccla(reg_type_rp_sccla.LAST).mto_riesgo:=rp_sccla.mto_riesgo;
          reg_type_rp_sccla(reg_type_rp_sccla.LAST).sal_cap_vencido:=rp_sccla.sal_cap_vencido;
          reg_type_rp_sccla(reg_type_rp_sccla.LAST).sal_int_vencido:=rp_sccla.sal_int_vencido;
          reg_type_rp_sccla(reg_type_rp_sccla.LAST).tot_garantia:=rp_sccla.tot_garantia;
          reg_type_rp_sccla(reg_type_rp_sccla.LAST).tot_cap_pri_prevision:=rp_sccla.tot_cap_pri_prevision;
          reg_type_rp_sccla(reg_type_rp_sccla.LAST).tot_cap_seg_prevision:=rp_sccla.tot_cap_seg_prevision;
          reg_type_rp_sccla(reg_type_rp_sccla.LAST).tot_int_pri_prevision:=rp_sccla.tot_int_pri_prevision;
          reg_type_rp_sccla(reg_type_rp_sccla.LAST).tot_int_seg_prevision:=rp_sccla.tot_int_seg_prevision;
          reg_type_rp_sccla(reg_type_rp_sccla.LAST).tot_tc:=rp_sccla.tot_tc;
          reg_type_rp_sccla(reg_type_rp_sccla.LAST).tot_dc:=rp_sccla.tot_dc;
          reg_type_rp_sccla(reg_type_rp_sccla.LAST).tot_tr:=rp_sccla.tot_tr;
          reg_type_rp_sccla(reg_type_rp_sccla.LAST).tot_dr:=rp_sccla.tot_dr;
          reg_type_rp_sccla(reg_type_rp_sccla.LAST).tot_er:=rp_sccla.tot_er;
          reg_type_rp_sccla(reg_type_rp_sccla.LAST).tot_sr:=rp_sccla.tot_sr;
          reg_type_rp_sccla(reg_type_rp_sccla.LAST).cod_persona:=rp_sccla.cod_persona;
          reg_type_rp_sccla(reg_type_rp_sccla.LAST).mto_vta_cartera:=rp_sccla.mto_vta_cartera;
          reg_type_rp_sccla(reg_type_rp_sccla.LAST).mto_deu_incobrable:=rp_sccla.mto_deu_incobrable;
      reg_type_rp_sccla(reg_type_rp_sccla.LAST).por_ing_mon_extranjera:=rp_sccla.por_ing_mon_extranjera;

         IF v_mensaje IS NOT NULL THEN
             reg_slcrc.EXTEND(1);
             reg_slcrc(reg_slcrc.LAST).fecha:= rp_sccla.fecha;
             reg_slcrc(reg_slcrc.LAST).nom_referencia:= rp_sccla.nom_referencia;
             reg_slcrc(reg_slcrc.LAST).usu_insercion:= V_USER;
             reg_slcrc(reg_slcrc.LAST).fecha:= SYSDATE;
             reg_slcrc(reg_slcrc.LAST).mensaje:= 'ERROR: Persona = ' ||rp_sccla.cod_persona || ': ' || v_mensaje || '; Nro. Registro: ' ||
                                           rp_sccla.nro_registro;
             reg_slcrc(reg_slcrc.LAST).nro_registro:= rp_sccla.nro_registro;
             reg_slcrc(reg_slcrc.LAST).fecha:=rp_sccla.fecha;
         END IF;

      END LOOP;

      EXIT WHEN c_clasifica%NOTFOUND;
          END LOOP;
          CLOSE c_clasifica;

      lp_ins_crc_clasificaciones(reg_type_rp_sccla); --> Inserta clasificaciones en bulk
      lp_log_crc(reg_slcrc);  --> Inserta Mensajes de errores

      lp_act_tot_registro(v_fec_fin, 'SB_CRC_CLASIFICACIONES');

 OPEN c_conyuge;
  LOOP
    FETCH c_conyuge BULK COLLECT INTO reg_conyuge LIMIT 10000;
    -- Salida segura: verifica que existan datos en la colección
    EXIT WHEN reg_conyuge.COUNT = 0;

    BEGIN
        FORALL i IN 1..reg_conyuge.COUNT
            MERGE INTO sb_crc_clasificaciones_det x
            USING (
                SELECT reg_conyuge(i).nro_documento as nro_documento,
                       reg_conyuge(i).mto_rie_codeudor as mto_rie_codeudor,
                       reg_conyuge(i).tot_garantia as tot_garantia
                FROM dual
            ) src
            ON (x.nro_documento = src.nro_documento AND x.fecha = v_fec_fin)
            WHEN MATCHED THEN
                UPDATE SET
                    -- Actualiza tot_sr solo si el monto es > 0, de lo contrario mantiene el valor actual
                    x.tot_sr = CASE WHEN nvl(src.mto_rie_codeudor, 0) > 0 THEN src.mto_rie_codeudor ELSE x.tot_sr END,
                    -- Actualiza tot_garantia solo si el monto es > 0
                    x.tot_garantia = CASE WHEN nvl(src.tot_garantia, 0) > 0 THEN src.tot_garantia ELSE x.tot_garantia END
                WHERE nvl(src.mto_rie_codeudor, 0) > 0 OR nvl(src.tot_garantia, 0) > 0;

    EXCEPTION
        WHEN OTHERS THEN
            -- Logging para trazabilidad en ambiente de producción
            DBMS_OUTPUT.PUT_LINE('Error procesando lote: ' || SQLERRM);
            RAISE;
    END;
  END LOOP;
CLOSE c_conyuge;

      --Actualizacion masiva.
      IF p_tip_proceso = 'M' THEN
         BEGIN
            DELETE FROM sb_crc_clasificaciones_det
             WHERE (nvl(mto_rie_contingente, 0) = 0 AND nvl(mto_riesgo, 0) = 0 AND
                   nvl(sal_cap_vencido, 0) = 0 AND nvl(sal_int_vencido, 0) = 0 AND
                   nvl(tot_garantia, 0) = 0 AND nvl(tot_cap_pri_prevision, 0) = 0 AND
                   nvl(tot_cap_seg_prevision, 0) = 0 AND nvl(tot_int_pri_prevision, 0) = 0 AND
                   nvl(tot_int_seg_prevision, 0) = 0 AND nvl(tot_tc, 0) = 0 AND nvl(tot_dc, 0) = 0 AND
                   nvl(tot_tr, 0) = 0 AND nvl(tot_dr, 0) = 0 AND nvl(tot_er, 0) = 0 AND
                   nvl(tot_sr, 0) = 0 /*AND nvl(tot_tf, 0) = 0*/ AND nvl(mto_vta_cartera, 0) = 0 AND
                   nvl(mto_deu_incobrable, 0) = 0)
               AND fecha = v_fec_fin;

            UPDATE sb_crc_clasificaciones_det SET nro_registro = rownum WHERE fecha = v_fec_fin;
         END;
      END IF;
      -- Actualizacion de personas_ref_ext.
      IF v_act_personas_ref = 'S' AND p_tip_proceso <> 'M' THEN
         pr_act_dat_cla_crc(v_fec_fin);
      END IF;
   END;



   FUNCTION fu_obt_mto_interes(p_nro_cuenta    IN ge_cuentas.nro_cuenta%TYPE,
                               p_cod_modalidad IN ge_cuentas.cod_modalidad%TYPE) RETURN NUMBER IS
      v_mto_interes ah_cupones.mto_interes%TYPE;
   BEGIN
      IF p_cod_modalidad IN (33, 34) THEN
         SELECT SUM(nvl(mto_interes, 0))
           INTO v_mto_interes
           FROM ah_cupones
          WHERE nro_cuenta = p_nro_cuenta
            AND estado IN ('E', 'C');
      END IF;
      RETURN v_mto_interes;
   EXCEPTION
      WHEN no_data_found THEN
         RETURN 0;
      WHEN OTHERS THEN
         RETURN 0;
   END;

FUNCTION fu_obt_mto_interes(p_nro_cuenta IN ge_cuentas.nro_cuenta%TYPE)
      RETURN NUMBER IS
      v_mto_interes   ah_cupones.mto_interes%TYPE;
   BEGIN
      SELECT SUM(nvl(mto_interes, 0))
        INTO v_mto_interes
        FROM ah_cupones
       WHERE nro_cuenta = p_nro_cuenta
         AND estado IN ('E', 'C');
      RETURN v_mto_interes;

      EXCEPTION
      WHEN NO_DATA_FOUND THEN
         return 0;
      WHEN OTHERS THEN
         return 0;
   END;
   -- Procedimientos que contiene los datos exigidos para el modulo de Prestamos
   PROCEDURE pr_crc_gen_prestamos IS

      CURSOR c_prestamos IS
         SELECT p.nro_cuenta, p.cod_oficina, p.cod_moneda, p.cod_modulo, p.cod_modalidad,
                decode(v_cod_entidad, 2036, p.fec_inicio,v.fecha) fec_inicio, p.fec_vencimiento, p.mto_capital,
                p.can_cuotas, p.cod_sec_credito, p.val_tasa, b.cod_persona, p.tipo, p.estado, p.estado est_prestamo,
                p.est_batch
           FROM pr_cta_prestamos p, ge_est_cuentas g, ge_cta_clientes b,
                (SELECT nro_cuenta, fecha
                    FROM ge_cuentas_nov v
                   WHERE v.fecha BETWEEN v_fec_inicio AND v_fec_fin
                     AND v.est_anterior IS NULL
                     AND v.est_actual = 'C') v
          WHERE p.nro_cuenta = b.nro_cuenta
            AND b.relacion = 'P'
            AND p.cod_modulo = g.cod_modulo
            AND p.cod_modalidad = g.cod_modalidad
            AND p.estado = g.estado

            AND ((v_cod_entidad = 6004 AND nvl(p.tip_renovacion, 'A') <> 'N') OR (v_cod_entidad <> 6004))
            AND (g.activo = 'S' OR (p.estado = 'N' AND p.cod_modalidad = 660 AND fec_inicio - fec_cancelacion = 0 AND
                EXISTS (SELECT 1
                                             FROM pr_cobros a
                                            WHERE a.nro_cuenta = b.nro_cuenta)))
            AND v.nro_cuenta(+) = p.nro_cuenta
            AND ((v_cod_entidad <> 2036 AND v.fecha BETWEEN v_fec_inicio AND v_fec_fin) OR
                (v_cod_entidad = 2036 AND p.fec_inicio BETWEEN v_fec_inicio AND v_fec_fin))
            AND NOT EXISTS
           (SELECT 1
                    FROM sb_crc_operaciones_det c
                   WHERE substr(c.nro_operacion, 1, instr(c.nro_operacion, '#') - 1) = p.nro_cuenta);
        -- no se informa como operacion de la 51mil solo se cambia el rubro en saldos.
       /*  UNION
         SELECT s.nro_cuenta, s.cod_oficina, s.cod_moneda, s.cod_modulo, s.cod_modalidad, s.fec_inicio,
                s.fec_vencimiento, s.mto_capital, s.can_cuotas, s.cod_sec_credito, s.val_tasa, s.cod_persona, s.tipo,
                s.estado, s.estado est_prestamo, s.est_batch, 'S'
           FROM pr_vta_carteras s
          WHERE s.estado = 'C'
            AND NOT EXISTS (SELECT 1
                   FROM sb_crc_operaciones_det c
                  WHERE c.nro_operacion = s.nro_cuenta)*/

      v_rub_contable        cb_rubros.cod_rubro%TYPE;
      v_cod_persona         ba_personas.cod_persona%TYPE;
      v_cod_rub_economico   sb_crc_operaciones_det.cod_rub_economico%TYPE;
      v_mto_interes         pr_cuotas.mto_interes%TYPE;
      v_mto_int_documentado pr_cuotas.mto_int_documentado%TYPE;
      v_mto_capital         pr_cuotas.mto_capital%TYPE;
      v_cod_transaccion     ge_transacciones.cod_transaccion%TYPE;
      v_fec_pas_incobrable  sb_crc_operaciones_det.fecha%TYPE;
      rg_gcope              sb_crc_operaciones_det%ROWTYPE;
      v_ins_vinculos_nov    VARCHAR2(1) DEFAULT 'N';
      rv_scvno              sb_cta_vinculos_nov%ROWTYPE;
      v_nro_documento       ge_che_custodias.nro_cheque%TYPE;
      v_nro_doc_lib         ba_personas.nro_documento%type;
      v_nro_cheque          number := 0;
      v_nro_cuota           pr_cuotas.nro_cuota%TYPE;

     FUNCTION lf_ver_cta_renovada(p_nro_cuenta pr_cta_prestamos.nro_cuenta%TYPE) RETURN VARCHAR2 IS
        v_cta_original pr_cta_prestamos.nro_cuenta%TYPE;
        v_can_cuotas   pr_cta_prestamos.can_cuotas%TYPE;
     BEGIN
        SELECT nro_cuenta
          INTO v_cta_original
          FROM pr_cta_prestamos g
         WHERE g.nro_cta_renovada = p_nro_cuenta;
        SELECT nro_cuo_hasta - nro_cuo_desde
          INTO v_can_cuotas
          FROM pr_cobros_rrr g
         WHERE nro_cuenta = v_cta_original;
         IF v_can_cuotas is not null then
            v_can_Cuotas := v_can_Cuotas + 1;
            RETURN v_cta_original || '##' || v_can_cuotas;
         ELSE
            RETURN NULL;
         END IF;
     EXCEPTION
        WHEN no_Data_found THEN
           RETURN NULL;
        WHEN OTHERS THEN
           RETURN NULL;
     END;
   BEGIN
      rg_gcope.nom_referencia := 'OPERACION';
      rg_gcope.nro_formulario := '001';
      FOR i IN c_prestamos LOOP

         v_fec_pas_incobrable := to_date(fug_obt_paradicional(i.nro_cuenta, 'PRE_FEC_PAS_INCOBRABLE'), 'dd/mm/yyyy');
         IF i.estado = 'N' THEN
            IF i.tipo = 'A' THEN
               v_cod_transaccion := 801;
            ELSE
               v_cod_transaccion := 805;
            END IF;
            v_rub_contable := IT.pas_cri.fu_obt_cod_rubro(i.nro_cuenta,null,null, v_cod_transaccion, null,null,null,null,null, 'C',null,'C',null,null,null,i.tipo,null);
         ELSE
            IF fu_obt_cod_entidad = 6004 AND i.cod_modalidad IN (628/*, 629*/) THEN
               --Prestamos AFD.
               v_rub_contable := pab_asi.fu_obt_rub_contable(i.nro_cuenta, 'F');
            ELSE
               v_rub_contable := pab_asi.fu_obt_rub_contable(i.nro_cuenta, 'C');
         IF v_rub_contable IS NULL THEN
                  v_rub_contable := pab_asi.fu_obt_rub_contable(i.nro_cuenta, 'F');
          END IF;
            END IF;
         END IF;

         v_cod_persona              := fug_obt_cli_principal(i.nro_cuenta);
         rg_gcope.cod_rub_primario  := fu_obt_rub_primario(v_cod_persona);
         IF fup_obt_tip_descuento(i.cod_modalidad) IS NULL OR nvl(fug_obt_pardinamico('SIB_MAD_EXC_FORMATO',6 ,i.cod_modalidad), 'N') = 'S' THEN
            rg_gcope.tip_operacion        := substr(v_rub_contable, 6, 3);
            rg_gcope.cta_con_cap_original := v_rub_contable;
            ---
            rg_gcope.cod_persona   := i.cod_persona;
            rg_gcope.cod_modulo    := i.cod_modulo;
            rg_gcope.fecha         := v_fec_fin;
            rg_gcope.cod_oficina   := i.cod_oficina;
            rg_gcope.nro_operacion := i.nro_cuenta;
            rg_gcope.cod_moneda    := fu_obt_mon_iso(i.cod_moneda);
            rg_gcope.fec_operacion := i.fec_inicio;
            ---
            SELECT MIN(fec_vencimiento), SUM(nvl(mto_interes, 0)), SUM(nvl(mto_int_documentado, 0))
              INTO rg_gcope.fec_pri_vencimiento, v_mto_interes, v_mto_int_documentado
              FROM pr_cuotas
             WHERE nro_cuenta = i.nro_cuenta
               AND estado <> 'N'
               AND nro_cuota > 0;
            ---
            IF i.cod_modalidad = 660 THEN
               rg_gcope.fec_pri_vencimiento := rg_gcope.Fec_Operacion + 1;
               rg_gcope.dia_plazo           := 1;
            ELSE
               rg_gcope.dia_plazo := i.fec_vencimiento - i.fec_inicio;
            END IF;
            ---
            rg_gcope.nro_cuota       := i.can_cuotas;

            --si es compra de cartera dejar el capital con el monto original sin sumar interes adelantado fieldesk-8230
            if fug_obt_pardinamico('SIB_CRC_MAD_COMPRA',I.COD_MODULO,I.COD_MODALIDAD,NULL,NULL) = 'S' then
              rg_gcope.mto_ori_capital := nvl(i.mto_capital, 0);
              rg_gcope.mto_ori_interes := v_mto_interes + v_mto_int_documentado;
            else
              rg_gcope.mto_ori_capital := nvl(i.mto_capital, 0) + nvl(v_mto_int_documentado, 0);
              rg_gcope.mto_ori_interes := v_mto_interes + v_mto_int_documentado;
            end if;
            ---------fieldesk-8230

            rg_gcope.mto_lin_credito := 0;
            IF rg_gcope.mto_ori_interes > 0 THEN
               rg_gcope.cta_con_int_original := pab_asi.fu_obt_rub_contable(i.nro_cuenta, 'I');
            ELSE
               rg_gcope.cta_con_int_original := NULL;
            END IF;
            --
            v_cod_rub_economico        := fu_obt_rub_economico(i.nro_cuenta, 'PR_CTA_PRESTAMOS');
            rg_gcope.cod_rub_economico := fu_obt_cod_bcp(v_cod_rub_economico);
            rg_gcope.cod_departamento  := fu_obt_ref_bco_central(fu_obt_cod_dep_destino(i.nro_cuenta,
                                                                                        'PR_CTA_PRESTAMOS'));
            IF rg_gcope.cod_departamento IS NULL THEN
               rg_gcope.cod_departamento := fu_obt_ref_bco_central(v_cod_persona);
            END IF;
            IF trim(rg_gcope.cod_departamento) IS NULL THEN
               rg_gcope.cod_departamento := 'B0';
            END IF;
            ---
            rg_gcope.tas_nominal := i.val_tasa;
            ---
         ELSIF fup_obt_tip_descuento(i.cod_modalidad) IS NOT NULL AND nvl(fug_obt_pardinamico('SIB_MAD_EXC_FORMATO',6 ,i.cod_modalidad), 'N') = 'N' THEN
            DECLARE
               CURSOR c_emisores IS
              SELECT a.nro_cuenta, a.cheque, a.cta_libradora, a.nro_cuota, a.fec_vencimiento
                FROM (SELECT f.nro_cuenta,
                     (to_char(a.nro_cheque)) cheque,
                     a.cta_libradora,
                     a.nro_cuota,
                     u.fec_vencimiento
                FROM ge_che_custodias a, pr_cta_prestamos f, pr_cuotas u
               WHERE a.nro_referencia = i.nro_cuenta
                 AND a.nro_referencia = u.nro_cuenta
                 AND f.nro_cuenta = u.nro_cuenta
                 AND a.nro_cuota = u.nro_cuota
                 AND f.nro_cuenta = a.nro_referencia
                 AND a.estado IN ('A', 'B', 'C')
                 AND nvl(f.est_batch, 'C') <> 'N' -- No canceladas
                 AND nvl(fup_obt_tip_descuento(f.cod_modalidad), 'X') IN ('D', 'C')
                 AND v_inc_emisores = 'S'
              /* GROUP BY f.nro_cuenta, e.nro_documento,b.cta_libradora*/
                ) a
                  UNION
                  -- Emisores Descuento de documentos
                 SELECT a.nro_cuenta, NULL,a.documento, a.nro_cuota, a.fec_vencimiento
                  FROM (SELECT pr.nro_cuenta, (d.documento) documento, d.nro_cuota, cu.fec_vencimiento
                          FROM pr_documentos d, pr_cta_prestamos pr, pr_cuotas cu
                         WHERE d.estado = 'C'
                           AND d.nro_referencia = pr.nro_cuenta
                           AND pr.nro_cuenta = i.nro_cuenta
                           AND d.nro_referencia = cu.nro_cuenta
                           AND d.nro_cuota = cu.nro_cuota
                           AND pr.nro_cuenta = cu.nro_cuenta
                           AND nvl(pr.est_batch, 'C') <> 'N' -- No canceladas
                           AND cu.estado <> 'N'
                           AND nvl(fup_obt_tip_descuento(pr.cod_modalidad), 'X') IN ('D', 'C')
                           AND pr.nro_cuenta = d.nro_referencia
                          AND v_inc_emisores = 'S'
                        ) a;
            BEGIN
               FOR c in c_emisores LOOP
                  rg_gcope.tip_operacion        := substr(v_rub_contable, 6, 3);
                  rg_gcope.cta_con_cap_original := v_rub_contable;
                  ---
                  rg_gcope.cod_modulo  := i.cod_modulo;
                  rg_gcope.fecha       := v_fec_fin;
                  rg_gcope.cod_oficina := i.cod_oficina;

                  rg_gcope.cod_moneda    := fu_obt_mon_iso(i.cod_moneda);
                  rg_gcope.fec_operacion := i.fec_inicio;
                  rg_gcope.fec_pri_vencimiento := c.fec_vencimiento;
                  ---
                  --- Porcion para Descuento de Cheques
                  IF fup_obt_tip_descuento(i.cod_modalidad) = 'C' THEN
                     SELECT SUM(nvl(mto_int_documentado, 0)), SUM(nvl(mto_capital, 0))
                       INTO  v_mto_int_documentado, v_mto_capital
                        FROM pr_cuotas cu, ge_che_custodias ge
                       WHERE nro_cuenta = i.nro_cuenta
                         AND cu.nro_cuenta = ge.nro_referencia
                         AND cu.nro_cuota = ge.nro_cuota
                         AND ge.nro_cheque = c.cheque
                         AND ge.cta_libradora = c.cta_libradora
                         AND cu.estado <> 'N'
                         AND cu.nro_cuota = c.nro_cuota;
                  ELSIF fup_obt_tip_descuento(i.cod_modalidad) = 'D' THEN
                     --- Porcion para Descuento de Documentos
                     SELECT SUM(nvl(mto_int_documentado, 0)), SUM(nvl(mto_capital, 0))
                       INTO v_mto_int_documentado, v_mto_capital
                       FROM pr_cuotas cu, pr_documentos ge
                      WHERE nro_cuenta = i.nro_cuenta
                        AND cu.nro_cuenta = ge.nro_referencia
                        AND cu.nro_cuota = ge.nro_cuota
                        AND cu.estado <> 'N'
                        AND cu.nro_cuota = c.nro_cuota;

                  END IF;
                  v_nro_doc_lib := null;
                  v_nro_cheque  := null;
                  -- en el caso que hubiere dos libradores informar solo uno
                  -- Se modifica para que informe el numero de cheque.
                   BEGIN
                      SELECT documento, cod_persona, nro_cheque
                        INTO v_nro_doc_lib, rg_gcope.cod_persona, v_nro_cheque
                        FROM sv_libradores
                       WHERE nro_cuenta = i.nro_cuenta
                         AND nro_cuota = c.nro_cuota
                         AND rownum = 1;
                   EXCEPTION
                      WHEN no_data_found THEN
                         v_nro_doc_lib := NULL;
                         v_nro_cheque  := NULL;
                   END;
                  rg_gcope.nro_operacion        := i.nro_cuenta || '#' || c.nro_cuota || '#' || v_nro_doc_lib;
                  rg_gcope.mto_ori_capital      := nvl(v_mto_capital, 0);
                  rg_gcope.mto_ori_interes      := nvl(v_mto_int_documentado, 0);
                  rg_gcope.cta_con_int_original := pab_asi.fu_obt_rub_contable(i.nro_cuenta, 'I');
                  rg_gcope.mto_lin_credito      := 0;
                  --rg_gcope.cod_rub_primario     := fu_obt_rub_primario(c.cod_persona);
                  v_cod_rub_economico           := fu_obt_rub_economico(i.nro_cuenta, 'PR_CTA_PRESTAMOS');
                  rg_gcope.cod_rub_economico    := fu_obt_cod_bcp(v_cod_rub_economico);
                  rg_gcope.cod_departamento     := fu_obt_ref_bco_central(fu_obt_cod_dep_destino(i.nro_cuenta,
                                                                                                 'PR_CTA_PRESTAMOS'));
                  IF rg_gcope.cod_departamento IS NULL THEN
                     rg_gcope.cod_departamento := fu_obt_ref_bco_central(v_cod_persona);
                  END IF;
                  rg_gcope.tas_nominal := i.val_tasa;
                  rg_gcope.dia_plazo   := i.fec_vencimiento - i.fec_inicio;
                  rg_gcope.nro_cuota   := i.can_cuotas;
                  if fu_pue_env_bcp(rg_gcope.tip_operacion) = 'S' then
                     IF ((i.est_prestamo <> 'I') OR (i.est_prestamo = 'I' AND v_fec_pas_incobrable IS NULL) OR
                        (i.est_batch = 'I' AND v_fec_pas_incobrable IS NOT NULL AND
                        ((v_fec_actual - v_fec_pas_incobrable) <= v_crc_can_dia_incobrable))) THEN
                        v_nro_registro        := v_nro_registro + 1;
                        rg_gcope.nro_registro := v_nro_registro;
                        --- Inserta Operaciones
                        lp_ins_crc_operaciones(rg_gcope);
                     END IF;
                  ELSE
                     rg_gcope.nro_registro := NULL;
                     pr_ins_crc_ope_no_enviados(rg_gcope);
                  END IF;
               END LOOP;
            END;
         END IF;
         if lf_ver_cta_renovada(i.nro_cuenta) is not null then
            rg_gcope.nro_operacion        := lf_ver_cta_renovada(i.nro_cuenta);
         end if;

         IF fup_obt_tip_descuento(i.cod_modalidad) IS NULL OR nvl(fug_obt_pardinamico('SIB_MAD_EXC_FORMATO',6 ,i.cod_modalidad), 'N')= 'S' THEN
            IF fu_pue_env_bcp(rg_gcope.tip_operacion) = 'S' THEN
               IF ((i.est_prestamo <> 'I') OR (i.est_prestamo = 'I' AND v_fec_pas_incobrable IS NULL) OR
                  (i.est_batch = 'I' AND v_fec_pas_incobrable IS NOT NULL AND
                  ((v_fec_actual - v_fec_pas_incobrable) <= v_crc_can_dia_incobrable))) THEN
                  v_nro_registro        := v_nro_registro + 1;
                  rg_gcope.nro_registro := v_nro_registro;
                  --- Inserta Operaciones
                  lp_ins_crc_operaciones(rg_gcope);
               END IF;
          --  else
              -- rg_gcope.nro_registro := null;
             -- pr_ins_crc_ope_no_enviados(rg_gcope);
            END IF;
         end if;
      END LOOP;
   END;
   -- Procedimiento que contiene los datos exigidos para el modulo de Sobregiros
   PROCEDURE pr_crc_gen_sobregiros IS
      CURSOR c_sobregiros IS
         SELECT a.nro_cuenta,
                a.cod_oficina,
                a.cod_moneda,
                a.cod_modulo,
                a.cod_modalidad,
                nvl(a.sal_tot_batch, 0) - nvl(a.sal_ret_batch, 0) - nvl(a.sal_blo_batch, 0) monto,
                c.can_dias,
                CASE
                   WHEN c.can_dias <= 60 THEN
                    'S'
                   WHEN c.can_dias >= 61 AND c.can_dias <= 90 THEN
                    'V'
                   WHEN c.can_dias >= 91 AND c.can_dias <= 180 THEN
                    'G'
                   WHEN c.can_dias >= 181 AND c.can_dias <= 360 THEN
                    'M'
                   ELSE
                    'I'
                END sit_deuda,
                c.fecha,
                pag_cal.fu_obt_fec_habil(c.fecha, -1, a.cod_oficina) fec_hab_sobregiro,
                c.mto_linea,
                b.cod_persona,
                i.situacion,
                i.cod_rubro
           FROM cc_cta_corrientes a, cc_sobregiros c, ge_cta_clientes b, cb_sal_inventarios_det d, cb_sal_inventarios i
          WHERE a.nro_cuenta = b.nro_cuenta
            AND b.relacion = 'P'
            AND a.nro_cuenta = c.nro_cuenta
            and d.nro_cuenta = a.nro_cuenta
            and a.cod_sub_modalidad <> 19
            and i.nro_referencia = d.nro_referencia
            AND c.fecha BETWEEN v_fec_inicio AND v_fec_fin
            AND i.tip_saldo = 'C'
            and i.situacion <> 'N'
            AND c.fecha =
                (SELECT MAX(z.fecha)
                   FROM cc_sobregiros z
                  WHERE z.fecha BETWEEN v_fec_inicio AND v_fec_fin
                    AND z.nro_cuenta = c.nro_cuenta
                    AND ((z.can_dias BETWEEN 0 AND 1) OR
                        (z.can_dias > 1 AND z.fecha BETWEEN v_fec_inicio AND v_fec_fin)))
            AND NOT EXISTS (SELECT distinct 1
                              FROM sb_crc_operaciones_det r
                             WHERE r.nro_operacion = a.nro_cuenta
                               AND r.tip_operacion = substr(i.cod_rubro, 6, 3))
            AND fu_obt_tip_operacion(substr(i.cod_rubro,6,3), 'SIB_CRC_TIP_OPE_SOBREGIRO') = 'S'
        UNION -- sobregiros generados por saldo m?nimo de cuentas no incluidos en proceso prc_gen_sobregiros
         SELECT a.nro_cuenta,
                a.cod_oficina,
                a.cod_moneda,
                a.cod_modulo,
                a.cod_modalidad,
                nvl(a.sal_tot_batch, 0) - nvl(a.sal_ret_batch, 0) - nvl(a.sal_blo_batch, 0) monto,
                0 can_dias,
                'S' sit_deuda,
                v_fec_fin fecha,
                pag_cal.fu_obt_fec_habil(v_fec_fin, -1, a.cod_oficina) fec_hab_sobregiro,
                0 mto_linea,
                b.cod_persona,
                i.situacion,
                i.cod_rubro
           FROM cc_cta_corrientes a, ge_cta_clientes b, cb_sal_inventarios_det d, cb_sal_inventarios i
          WHERE a.nro_cuenta = b.nro_cuenta
            AND b.relacion = 'P'
            and d.nro_cuenta = a.nro_cuenta
            and a.cod_sub_modalidad <> 19
            and i.nro_referencia = d.nro_referencia
            AND (nvl(a.sal_tot_batch, 0) <> 0 OR nvl(a.sal_ret_batch, 0) <> 0 OR
                 nvl(a.sal_blo_batch, 0) <> 0)
            AND nvl(a.sal_tot_batch, 0) - nvl(a.sal_ret_batch, 0) - nvl(a.sal_blo_batch, 0) < 0
            AND i.tip_saldo = 'C'
            and i.situacion <> 'N'
            AND NOT EXISTS (SELECT 0
                              FROM cc_sobregiros z
                             WHERE z.fecha BETWEEN v_fec_inicio AND v_fec_fin
                               AND z.nro_cuenta = a.nro_cuenta)
            AND NOT EXISTS (SELECT distinct 1
                              FROM sb_crc_operaciones_det r
                             WHERE r.nro_operacion = a.nro_cuenta
                               AND r.tip_operacion = substr(i.cod_rubro, 6, 3))
            AND fu_obt_tip_operacion(substr(i.cod_rubro,6,3), 'SIB_CRC_TIP_OPE_SOBREGIRO') = 'S'
        UNION -- cuentas con l?neas que no est?n sobregiradas
         SELECT a.nro_cuenta,
                a.cod_oficina,
                a.cod_moneda,
                a.cod_modulo,
                a.cod_modalidad,
                0 monto,
                0 can_dias,
                'S' sit_deuda,
                v_fec_fin fecha,
                pag_cal.fu_obt_fec_habil(v_fec_fin, -1, a.cod_oficina) fec_hab_sobregiro,
                a.linea mto_linea,
                a.cod_persona,
                'S' situacion,
                null cod_rubro/*decode(a.cod_moneda, 'GS', '142101870222299', '142101870222205') cod_rubro*/
           FROM pv_cat_sobregiros a, cc_cta_corrientes c
          WHERE a.sal_actual = 0 --solo l?neas con sobregiro
            and a.cod_modulo = c.cod_modulo
            and a.cod_modalidad = c.cod_modalidad
            and a.nro_cuenta = c.nro_cuenta
            and c.cod_sub_modalidad <> 19
            AND NOT EXISTS (SELECT distinct 1
                              FROM sb_crc_operaciones_det r
                             WHERE r.nro_operacion = a.nro_cuenta
                               AND IT.pas_cri.fu_obt_tip_operacion(r.tip_operacion, 'SIB_CRC_TIP_OPE_SOB_PER') = 'S')
           -----
           UNION
           ---INFORMAR SOBREGIRO PROVENIENTE DE CANCELACION PRESTAMO WEB-ATM-MOBILE
           SELECT c.nro_cuenta,
                  c.cod_oficina,
                  c.cod_moneda,
                  c.cod_modulo,
                  c.cod_modalidad,
                  0 monto,
                  0 can_dias,
                  'S' sit_deuda,
                  v_fec_fin fecha,
                  pag_cal.fu_obt_fec_habil(v_fec_fin, -1, c.cod_oficina) fec_hab_sobregiro,
                  abs(c.sal_total) mto_linea,
                  g.cod_persona,
                  'S' situacion,
                  null cod_rubro /*decode(c.cod_moneda, 'GS', '142101890211199', '142101890211105') cod_rubro*/
             FROM cc_cta_corrientes c, ge_cta_clientes g
            WHERE c.cod_sub_modalidad = 19
              and c.fec_apertura BETWEEN v_fec_inicio AND  v_fec_fin
              and c.nro_cuenta = g.nro_cuenta
              and c.cod_modulo = g.cod_modulo
              and c.cod_modalidad = g.cod_modalidad
              and g.relacion = 'P'
              AND NOT EXISTS (SELECT distinct 1
                                          FROM sb_crc_operaciones_det r
                                         WHERE r.nro_operacion = c.nro_cuenta
                                           AND r.tip_operacion = 189);
      --
      v_rub_contable      cb_rubros.cod_rubro%TYPE;
      v_tip_operacion     sb_crc_operaciones_det.tip_operacion%TYPE;
      v_cod_persona       ba_personas.cod_persona%TYPE;
      v_cod_transaccion   ge_transacciones.cod_transaccion%TYPE;
      v_cod_tasa          ge_tas_fechas.cod_tasa%TYPE;
      v_val_tasa          ge_tas_fechas.val_tasa%TYPE;
      v_fec_vigencia      ge_tas_fechas.fec_vigencia%TYPE;
      v_tip_valor         ge_tasas.tip_valor%TYPE;
      v_tipo              ge_tasas.tipo%TYPE;
      v_cod_rub_economico sb_crc_operaciones_det.cod_rub_economico%TYPE;
      rg_gcope            sb_crc_operaciones_det%ROWTYPE;
   BEGIN
      rg_gcope.nom_referencia := 'OPERACION';
      rg_gcope.nro_formulario := '001';
      FOR i IN c_sobregiros LOOP
         v_rub_contable := i.cod_rubro;
         IF v_rub_contable IS NULL THEN
            v_rub_contable := pab_asi.fu_obt_rub_con_his(i.nro_cuenta, 'C', i.fec_hab_sobregiro,
                                                         i.situacion);
         END IF;

         v_tip_operacion := substr(v_rub_contable, 6, 3);
         IF v_tip_operacion NOT IN (265, 269, 275) THEN
            rg_gcope.tip_operacion := v_tip_operacion;
            v_existe := 'N';
         ELSE
            BEGIN
              SELECT val_minimo
                INTO rg_gcope.tip_operacion
                FROM ba_cod_referencias
               WHERE dominio = 'SIB_CRC_TIP_OPE_SOB_TEM';
            EXCEPTION
              WHEN OTHERS THEN
                rg_gcope.tip_operacion := v_tip_operacion;
            END;
            BEGIN
               SELECT DISTINCT 'S'
                 INTO v_existe
                 FROM sb_crc_operaciones_det r
                WHERE r.nro_operacion = i.nro_cuenta
                  AND r.tip_operacion = rg_gcope.tip_operacion;
            EXCEPTION
               WHEN no_data_found THEN
                  v_existe := 'N';
               WHEN OTHERS THEN
                  v_existe := 'N';
            END;
         END IF;
         IF fu_pue_env_bcp(rg_gcope.tip_operacion) = 'S' AND v_existe = 'N' THEN
            rg_gcope.cta_con_cap_original := v_rub_contable;
            ---
            rg_gcope.cod_persona   := i.cod_persona;
            rg_gcope.fecha         := v_fec_fin;
            rg_gcope.cod_modulo    := i.cod_modulo;
            rg_gcope.cod_oficina   := i.cod_oficina;
            rg_gcope.nro_operacion := i.nro_cuenta;
            rg_gcope.cod_moneda    := fu_obt_mon_iso(i.cod_moneda);
            rg_gcope.fec_operacion := i.fecha;
            IF v_cod_entidad = 1007 AND rg_gcope.tip_operacion = 215 THEN
               rg_gcope.fec_pri_vencimiento := i.fecha + 1;
            ELSE
               rg_gcope.fec_pri_vencimiento := i.fecha;
            END IF;
            rg_gcope.nro_cuota            := 0;
            rg_gcope.mto_ori_capital      := 0;
            rg_gcope.mto_ori_interes      := 0;
            rg_gcope.mto_lin_credito      := i.mto_linea;
            IF i.monto <> 0 THEN
            rg_gcope.cta_con_int_original := pab_asi.fu_obt_rub_contable(i.nro_cuenta, 'I');
            ELSE
               rg_gcope.cta_con_int_original := NULL;
            END IF;
            ---
            v_cod_persona             := fug_obt_cli_principal(i.nro_cuenta);
            rg_gcope.cod_rub_primario := fu_obt_rub_primario(v_cod_persona);
            v_cod_rub_economico       := fu_obt_rub_economico(i.nro_cuenta, 'CC_LIN_SOBREGIROS');
            IF v_cod_rub_economico IS NULL THEN
               v_cod_rub_economico := nvl(fug_obt_pardinamico('COD_RUB_ECO_PRE_APR_ATM', i.cod_modulo), '970108');
            END IF;
            rg_gcope.cod_rub_economico := fu_obt_cod_bcp(v_cod_rub_economico);
            rg_gcope.cod_departamento  := fu_obt_ref_bco_central(v_cod_persona);
            ---
            rg_gcope.dia_plazo := 0;
            /**
            || Sobregiros: Transacci?n 980 = Donde la Situaci?n del Sobregiro sea distinta a  'S' o 'V'
            || De lo contrario Utilizar la transacci?n 550 para obtener la tasa nominal.
            **/
            IF i.monto <> 0 THEN
            IF i.sit_deuda IN ('S', 'V') AND fu_obt_cod_entidad <> 1028 THEN
               v_cod_transaccion := 980;
            ELSE
               v_cod_transaccion := 550;
            END IF;
            v_cod_tasa := NULL;
            pag_gen.pr_obt_val_tasa(i.cod_modulo, i.cod_modalidad, i.cod_oficina, i.nro_cuenta,
                                    i.cod_moneda, i.monto, 'N', v_cod_tasa, v_cod_transaccion,
                                    v_fec_actual, v_val_tasa, v_fec_vigencia, v_tip_valor, v_tipo);
            rg_gcope.tas_nominal := v_val_tasa;
            ELSE
               IF i.cod_moneda = pag_gen.fu_obt_mon_local THEN
                  rg_gcope.tas_nominal := 35;
               ELSE
                  rg_gcope.tas_nominal := 15.85;
               END IF;
            END IF;
            ---
            v_nro_registro        := v_nro_registro + 1;
            rg_gcope.nro_registro := v_nro_registro;
            --- Inserta Operaciones
            lp_ins_crc_operaciones(rg_gcope);
            --- Inserta Vinculos
          /*  lp_crc_gen_vinculos(rg_gcope.cod_oficina, rg_gcope.nro_operacion,
                                rg_gcope.tip_operacion, rg_gcope.cta_con_cap_original,
                                rg_gcope.cod_moneda);*/

         END IF;
      END LOOP;
   END;
   -- Procedimiento que contiene los datos exigidos para el modulo de Tarjetas
   PROCEDURE pr_crc_gen_tarjetas IS
      CURSOR c_tarjetas IS
         SELECT a.nro_cuenta, t.nro_tarjeta, a.cod_oficina, a.cod_moneda, a.cod_modulo, a.cod_modalidad, a.cod_tip_cierre,
                nvl(a.sal_facturar, 0) + nvl(a.sal_facturado, 0) + nvl(a.sal_financiado, 0) +
                 nvl(a.sal_cuo_pendientes, 0) monto, a.dia_mora,
                nvl(a.fec_activacion, pag_cal.fu_obt_fec_sig_hab(t.fec_emision, a.cod_oficina, 1)) fec_apertura,
                decode(nvl(a.tas_financiacion, 0), 0, a.tas_efectiva, a.tas_financiacion) tas_efectiva,
                decode(NVL(a.lin_credito, 0) + NVL(a.lin_cuotas, 0),
                        0,
                        nvl(c.mto_aprobado,c.monto),
                        NVL(a.lin_credito, 0) + NVL(a.lin_cuotas, 0)) lin_credito, a.fec_ult_cierre fec_vct_ult_cierre,
                t.fec_vencimiento, t.fec_activacion, b.cod_persona, a.nro_solicitud, nvl(c.fec_aprobacion, v_fec_fin)
           FROM ta_cta_tarjetas a, ge_est_cuentas g, ge_cta_clientes b, ta_tarjetas t, ta_solicitudes c
          WHERE a.nro_cuenta = b.nro_cuenta
            AND b.relacion = 'P'
            AND a.cod_modulo = g.cod_modulo
            AND a.cod_modalidad = g.cod_modalidad
            AND t.nro_cuenta = a.nro_cuenta
            AND a.estado = g.estado
            AND b.cod_persona = t.cod_persona
            AND g.activo = 'S'
            AND t.rel_tarjeta = 0
            --AND a.estado <> 'C'
            AND a.estado not in ('C','I') --fieldesk 3408--no tener en cuenta estado inactivo
            AND a.nro_solicitud = c.nro_solicitud(+)
            AND t.nro_tarjeta = (SELECT MAX(nro_tarjeta)
                                   FROM ta_tarjetas ttarj
                                  WHERE ttarj.nro_cuenta = b.nro_cuenta
                                    AND ttarj.cod_persona = b.cod_persona)
            AND NOT EXISTS
          (SELECT 1
                   FROM sb_crc_operaciones_det c
                  WHERE c.nro_operacion = a.nro_cuenta or c.nro_operacion = t.nro_tarjeta)
            AND nvl(t.fec_activacion, t.fec_emision) BETWEEN v_fec_ini_tarjeta - 15 AND v_fec_fin_tarjeta
            AND (CASE
                   WHEN ((v_cod_entidad IN (2079, 1043) AND t.vigente = 'S') OR
                        (v_cod_entidad NOT IN (1028, 1007, 2079, 1043))) THEN
                    1
                   ELSE
                    0
                END = 1)
            AND NOT EXISTS (SELECT 1
                   FROM ge_par_dinamicos p
                  WHERE p.parametro = 'SIB_CRC_MAD_EXC_ARCHIVO'
                    AND p.cod_modalidad = a.cod_modalidad
                    AND nvl(p.val_parametro, 'N') = 'S');

      v_rub_contable      cb_rubros.cod_rubro%TYPE;
      v_cod_persona       ba_personas.cod_persona%TYPE;
      v_cod_rub_economico sb_crc_operaciones_det.cod_rub_economico%TYPE;
      rg_gcope            sb_crc_operaciones_det%ROWTYPE;
   BEGIN
      rg_gcope.nom_referencia := 'OPERACION';
      rg_gcope.nro_formulario := '001';
      IF v_cod_entidad = 2079 AND v_fec_inicio = v_fec_fin THEN
         v_fec_ini_tarjeta := pag_cal.fu_obt_fec_ant_hab(v_fec_inicio, NULL, 1);
         v_fec_fin_tarjeta := pag_cal.fu_obt_fec_ant_hab(v_fec_fin, NULL, 1);
      ELSE
         v_fec_ini_tarjeta := v_fec_inicio;
         v_fec_fin_tarjeta := v_fec_fin;
      END IF;
      FOR i IN c_tarjetas LOOP
         v_rub_contable                := pab_asi.fu_obt_rub_contable(i.nro_cuenta, 'C');
  if substr(v_rub_contable, 6, 3) = '260' --NOR-21
         then
            v_rub_contable := fug_obt_pardinamico('TIP_OPE_CTA_TARJETA');
         end if;
         rg_gcope.tip_operacion        := substr(v_rub_contable, 6, 3);
         rg_gcope.cta_con_cap_original := v_rub_contable;
         rg_gcope.fecha                := v_fec_fin;
         rg_gcope.cod_persona          := i.cod_persona;
         rg_gcope.cod_oficina          := i.cod_oficina;
         rg_gcope.cod_modulo           := i.cod_modulo;

         if nvl(fug_obt_pardinamico('MAD_TAR_CRE_UENO',i.cod_modulo,i.cod_modalidad),'N') = 'S' then --fieldesk-19388 si es tc duo usar nro_cuenta

            rg_gcope.nro_operacion        := i.nro_cuenta;
         else
            rg_gcope.nro_operacion        := i.nro_tarjeta;
         end if;

         rg_gcope.cod_moneda           := fu_obt_mon_iso(i.cod_moneda);
         IF v_cod_entidad = 1007 THEN
            rg_gcope.fec_operacion := i.fec_apertura;
         ELSE
            rg_gcope.fec_operacion := v_fec_fin;
         END IF;
         IF v_cod_entidad = 6004 THEN
            IF i.fec_apertura < pat_imp.fu_obt_fec_cierre(fug_obt_pardinamico('COD_PRO_PROCARD'), i.cod_modalidad) THEN
               rg_gcope.fec_pri_vencimiento := pat_imp.fu_obt_fec_vencim(fug_obt_pardinamico('COD_PRO_PROCARD'),
                                                                         i.cod_modalidad);

            ELSIF i.fec_apertura >= pat_imp.fu_obt_fec_cierre(fug_obt_pardinamico('COD_PRO_PROCARD'), i.cod_modalidad) THEN
               rg_gcope.fec_pri_vencimiento := IT.pas_cri.fu_obt_sig_fec_vencimiento(fug_obt_pardinamico('COD_PRO_PROCARD'),
                                                                                  i.cod_modalidad,
                                                                                  i.fec_apertura);
            ELSE
               rg_gcope.fec_pri_vencimiento := i.fec_vct_ult_cierre;
            END IF;
         ELSIF v_cod_entidad = 2036 THEN
            rg_gcope.fec_pri_vencimiento := pat_imp.fu_obt_fec_vencim(fug_obt_pardinamico('COD_PRO_PROCARD'),
                                                                      i.cod_modalidad);
         ELSIF v_cod_entidad IN (2080, 1007) AND rg_gcope.tip_operacion IN (215, 205) THEN
            IF i.fec_apertura <
               pat_imp.fu_obt_fec_cierre(fug_obt_pardinamico('COD_PRO_BANCARD'), i.cod_modalidad, i.cod_tip_cierre) THEN
               rg_gcope.fec_pri_vencimiento := pat_imp.fu_obt_fec_vencim(fug_obt_pardinamico('COD_PRO_BANCARD'),
                                                                         i.cod_modalidad,
                                                                         i.cod_tip_cierre);

            ELSIF i.fec_apertura >
                  pat_imp.fu_obt_fec_cierre(fug_obt_pardinamico('COD_PRO_BANCARD'), i.cod_modalidad, i.cod_tip_cierre) THEN
               rg_gcope.fec_pri_vencimiento := IT.pas_cri.fu_obt_sig_fec_vencimiento(fug_obt_pardinamico('COD_PRO_BANCARD'),
                                                                                  i.cod_modalidad,
                                                                                  i.fec_apertura,
                                                                                  i.cod_tip_cierre);
            ELSE
               rg_gcope.fec_pri_vencimiento := i.fec_vct_ult_cierre;
            END IF;
         ELSE
            rg_gcope.fec_pri_vencimiento := i.fec_vct_ult_cierre;
         END IF;
         IF rg_gcope.fec_pri_vencimiento <= rg_gcope.fec_operacion or rg_gcope.fec_pri_vencimiento is null THEN
            rg_gcope.fec_pri_vencimiento := rg_gcope.fec_operacion + 1;
         END IF;
         rg_gcope.nro_cuota            := 0;
         rg_gcope.mto_ori_capital      := 0;
         rg_gcope.mto_ori_interes      := 0;
         rg_gcope.cta_con_int_original := pab_asi.fu_obt_rub_contable(i.nro_cuenta, 'I');
         ---
         v_cod_persona              := fug_obt_cli_principal(i.nro_cuenta);
         rg_gcope.mto_lin_credito   := i.lin_credito;
         rg_gcope.cod_rub_primario  := fu_obt_rub_primario(v_cod_persona);
         v_cod_rub_economico        := fu_obt_rub_economico(i.nro_cuenta, 'TA_CTA_TARJETAS');
         rg_gcope.cod_rub_economico := fu_obt_cod_bcp(v_cod_rub_economico);
         rg_gcope.cod_departamento  := fu_obt_ref_bco_central(v_cod_persona);
         IF trim(rg_gcope.cod_departamento) IS NULL THEN
            rg_gcope.cod_departamento := 'B0';
         END IF;
         ---
         IF v_cod_entidad = 1007 THEN
            rg_gcope.dia_plazo := i.fec_vencimiento - i.fec_apertura;
         ELSIF v_cod_entidad = 6004 THEN
            rg_gcope.dia_plazo := i.fec_vencimiento - rg_gcope.fec_operacion;
         ELSE
            rg_gcope.dia_plazo := i.fec_vencimiento - i.fec_activacion;
         END IF;
         rg_gcope.tas_nominal := i.tas_efectiva;
         IF fu_pue_env_bcp(rg_gcope.tip_operacion) = 'S'
             and fu_ope_existe(rg_gcope.nro_operacion, rg_gcope.tip_operacion) = 'N' THEN
            ---
            v_nro_registro        := v_nro_registro + 1;
            rg_gcope.nro_registro := v_nro_registro;
            --- Inserta Operaciones
            lp_ins_crc_operaciones(rg_gcope);
         ELSE
            rg_gcope.nro_registro := null;
            pr_ins_crc_ope_no_enviados(rg_gcope);
         END IF;
      END LOOP;
   END;

   -- Procedimiento que contiene los datos exigidos para el modulo de Comercio Exterior
   PROCEDURE pr_crc_gen_comex IS
      CURSOR c_comex IS
         SELECT a.nro_cuenta cta_comex,
                a.cod_oficina,
                a.cod_moneda,
                a.cod_modulo,
                a.cod_modalidad,
                CASE
                   WHEN a.nro_sol_prestamo IS NOT NULL THEN
                    c.mto_capital
                   ELSE
                    a.mto_original
                END monto,
                a.fec_aprobacion,
                'CX_CTA_IMPORTACIONES' tabla,
                fu_obt_rub_contable(a.cod_modulo, a.nro_cuenta, 'A') rubro,
                to_char(a.nro_sol_prestamo) nro_sol_prestamo,
                c.nro_cuenta cta_prestamo,
                'A' situacion,
                a.fec_vencimiento - a.fec_aprobacion dia_plazo,
                a.fec_vencimiento,
                a.fec_solicitud,
                b.cod_persona,
                1 nro_cuota
           FROM cx_cta_importaciones a, pr_solicitudes s, pr_cta_prestamos c, ge_cta_clientes b
          WHERE a.nro_cuenta = b.nro_cuenta
            AND b.relacion = 'P'
            AND a.estado IN ('A', 'U')
            AND s.nro_solicitud(+) = a.nro_sol_prestamo
            AND c.nro_solicitud(+) = s.nro_solicitud
            --AND a.fec_solicitud BETWEEN v_fec_inicio AND nvl(a.fec_aprobacion,v_fec_fin)
            AND v_fec_inicio BETWEEN a.fec_solicitud AND a.fec_aprobacion--Se modifica por incidencia
            AND a.fec_aprobacion IS NOT NULL
            AND a.saldo > 0
            AND NOT EXISTS (SELECT 1 FROM sb_crc_operaciones_det r
                                 WHERE r.nro_operacion = a.nro_cuenta
                                   AND r.tip_operacion = substr(IT.pas_cri.fu_obt_rub_contable(a.cod_modulo, a.nro_cuenta, 'A'), 6, 3))
         UNION ALL
         ----------------------------------------------------------------------------------------------------
         /*Cartas de Importaci?n Utilizaci?n*/
         SELECT a.nro_cuenta cta_comex,
                a.cod_oficina,
                a.cod_moneda,
                a.cod_modulo,
                a.cod_modalidad,
                CASE
                   WHEN a.nro_sol_prestamo IS NOT NULL THEN
                    c.mto_capital
                   ELSE
                    a.mto_original
                END monto,
                a.fec_aprobacion,
                'CX_CTA_IMPORTACIONES' tabla,
                IT.pas_cri.fu_obt_rub_contable(a.cod_modulo, a.nro_cuenta, 'U') rubro,
                to_char(a.nro_sol_prestamo) nro_sol_prestamo,
                c.nro_cuenta cta_prestamo,
                'U' situacion,
                --a.fec_vencimiento - a.fec_aprobacion dia_plazo,
                (select max(t.fec_vencimiento) from cx_embarques t where t.nro_cuenta=a.nro_cuenta) - a.fec_utilizacion dia_plazo,
                a.fec_vencimiento,
                a.fec_solicitud,
                b.cod_persona,
                (select max(t.nro_embarque) from cx_embarques t where t.nro_cuenta=a.nro_cuenta) nro_cuota
           FROM cx_cta_importaciones a, pr_solicitudes s, pr_cta_prestamos c, ge_cta_clientes b, ge_cuentas_nov v
          WHERE a.nro_cuenta = b.nro_cuenta
            AND b.relacion = 'P'
            AND a.estado NOT IN ('C', 'S')
            AND s.nro_solicitud(+) = a.nro_sol_prestamo
            AND c.nro_solicitud(+) = s.nro_solicitud
            AND v.nro_cuenta = b.nro_cuenta
            AND v.hora = (SELECT MAX(n.hora) hora
                            FROM ge_cuentas_nov n
                           WHERE n.nro_cuenta = v.nro_cuenta
                             AND n.est_anterior = 'A'
                             AND n.est_actual = 'U'
                             AND n.fecha BETWEEN v_fec_inicio AND v_fec_fin)
            AND v.est_anterior = 'A' -- A-ctiva
            AND v.est_actual = 'U' -- U-tilizada
            AND v.fecha BETWEEN v_fec_inicio AND v_fec_fin
            AND NOT EXISTS (SELECT 1 FROM sb_crc_operaciones_det r
                                 WHERE r.nro_operacion = a.nro_cuenta
                                   AND r.tip_operacion = substr(IT.pas_cri.fu_obt_rub_contable(a.cod_modulo, a.nro_cuenta, 'U'), 6, 3))
         UNION ALL
         ----------------------------------------------------------------------------------------------------
         /*Cartas de Exportaci?n*/
         SELECT a.nro_cuenta cta_comex,
                a.cod_oficina,
                a.cod_moneda,
                a.cod_modulo,
                a.cod_modalidad,
                CASE
                   WHEN a.nro_sol_prestamo IS NOT NULL THEN
                    c.mto_capital
                   ELSE
                    a.mto_original
                END monto,
                a.fec_aprobacion,
                'CX_CTA_EXPORTACIONES' tabla,
                CASE
                   WHEN a.monto <> a.saldo THEN
                    fu_obt_rub_contable(a.cod_modulo, a.nro_cuenta, 'U')
                   ELSE
                    fu_obt_rub_contable(a.cod_modulo, a.nro_cuenta, 'A')
                END rubro,
                to_char(a.nro_sol_prestamo) nro_sol_prestamo,
                c.nro_cuenta cta_prestamo,
                CASE
                   WHEN a.monto <> a.saldo THEN
                    'U'
                   ELSE
                    'A'
                END situacion,
                a.fec_vencimiento - a.fec_aprobacion dia_plazo,
                a.fec_vencimiento,
                a.fec_solicitud,
                b.cod_persona,
                0
           FROM cx_cta_exportaciones a, pr_cta_prestamos c, ge_cta_clientes b, pr_solicitudes s
          WHERE a.nro_cuenta = b.nro_cuenta
            AND b.relacion = 'P'
            AND s.nro_solicitud(+) = a.nro_sol_prestamo
            AND c.nro_solicitud(+) = s.nro_solicitud
            AND a.fec_aprobacion BETWEEN v_fec_inicio AND v_fec_fin
            AND a.saldo > 0
            AND fu_obt_cod_entidad != 1007;
      ------------------------------------------------------------------------------------------------
      v_rub_contable        cb_rubros.cod_rubro%TYPE;
      v_rub_capital         cb_rubros.cod_rubro%TYPE;
      v_cod_persona         ba_personas.cod_persona%TYPE;
      v_cod_rub_economico   sb_crc_operaciones_det.cod_rub_economico%TYPE;
      v_fec_vencimiento     sb_crc_operaciones_det.fecha%TYPE;
      rg_gcope              sb_crc_operaciones_det%ROWTYPE;
      v_mto_interes         pr_cuotas.mto_interes%TYPE;
      v_mto_int_documentado pr_cuotas.mto_int_documentado%TYPE;
   BEGIN
      rg_gcope.nom_referencia := 'OPERACION';
      rg_gcope.nro_formulario := '001';
      FOR i IN c_comex LOOP
         IF i.cta_prestamo IS NOT NULL THEN
            v_rub_contable := pab_asi.fu_obt_rub_contable(i.cta_prestamo, 'C');
            IF v_rub_contable IS NULL THEN
               v_rub_contable := fu_obt_rub_contable(i.cod_modulo, i.cta_comex, i.situacion );
            END IF;
         ELSE
            v_rub_contable := fu_obt_rub_contable(i.cod_modulo, i.cta_comex, i.situacion);
         END IF;
         rg_gcope.tip_operacion        := substr(v_rub_contable, 6, 3);
         v_rub_capital                 := fug_obt_pardinamico('SIB_CRC_RUB_CAP_CONTINGENTE', NULL, NULL, i.cod_moneda);
         rg_gcope.cta_con_cap_original := v_rub_capital;
         ---
         IF fu_pue_env_bcp(rg_gcope.tip_operacion) = 'S' THEN
            rg_gcope.cod_persona          := i.cod_persona;
            rg_gcope.fecha                := v_fec_fin;
            rg_gcope.cod_modulo           := i.cod_modulo;
            rg_gcope.cod_oficina          := i.cod_oficina;
            rg_gcope.nro_operacion        := i.cta_comex;
            rg_gcope.cod_moneda           := fu_obt_mon_iso(i.cod_moneda);
            rg_gcope.fec_operacion        := i.fec_solicitud;
            rg_gcope.nro_cuota            := i.nro_cuota;
            rg_gcope.mto_lin_credito      := 0;
            rg_gcope.cta_con_int_original := pab_asi.fu_obt_rub_contable(i.cta_prestamo, 'I');
            v_cod_persona                 := fug_obt_cli_principal(i.cta_comex);
            rg_gcope.cod_rub_primario     := fu_obt_rub_primario(v_cod_persona);
            v_cod_rub_economico           := fu_obt_rub_economico(i.cta_comex, i.tabla);
            rg_gcope.cod_rub_economico    := fu_obt_cod_bcp(v_cod_rub_economico);

            rg_gcope.cod_departamento := fu_obt_ref_bco_central(v_cod_persona);
            rg_gcope.dia_plazo        := i.dia_plazo;
            ---
            BEGIN
               SELECT p.val_tasa/*, p.fec_vencimiento - p.fec_inicio*/
                 INTO rg_gcope.tas_nominal/*, rg_gcope.dia_plazo*/
                 FROM pr_solicitudes s, pr_cta_prestamos p
                WHERE s.nro_solicitud = p.nro_solicitud
                  AND p.nro_solicitud = i.nro_sol_prestamo;
            EXCEPTION
               WHEN OTHERS THEN
                  rg_gcope.tas_nominal := 0;
                  --rg_gcope.dia_plazo   := 0;
            END;

            rg_gcope.mto_ori_interes := 0;
            rg_gcope.tas_nominal     := 0;

            BEGIN
               SELECT nvl(MIN(c.fec_vencimiento), i.fec_vencimiento),
                      nvl(SUM(c.mto_interes), 0),
                      nvl(SUM(c.mto_int_documentado), 0)
                 INTO v_fec_vencimiento, v_mto_interes, v_mto_int_documentado
                 FROM pr_cuotas c, pr_cta_prestamos p
                WHERE p.nro_solicitud = i.nro_sol_prestamo
                  AND c.nro_cuenta = p.nro_cuenta
                  AND nro_cuota > 0;
            EXCEPTION
               WHEN OTHERS THEN
                  rg_gcope.fec_pri_vencimiento := i.fec_vencimiento;
                  v_mto_interes                := 0;
                  v_mto_int_documentado        := 0;
            END;
            rg_gcope.fec_pri_vencimiento := nvl(v_fec_vencimiento, i.fec_vencimiento);
            rg_gcope.mto_ori_capital     := nvl(i.monto, 0) + nvl(v_mto_int_documentado, 0);
            rg_gcope.mto_ori_interes     := v_mto_interes + v_mto_int_documentado;
            v_nro_registro               := v_nro_registro + 1;
            rg_gcope.nro_registro        := v_nro_registro;
            --- Inserta Operaciones
            lp_ins_crc_operaciones(rg_gcope);
            --- Inserta Vinculos
            /*lp_crc_gen_vinculos(rg_gcope.cod_oficina, rg_gcope.nro_operacion,
                                rg_gcope.tip_operacion, rg_gcope.cta_con_cap_original,
                                rg_gcope.cod_moneda);*/
         END IF;
      END LOOP;
   END;
   -- Procedimiento que continee los datos exigidos para Fianzas
   PROCEDURE pr_crc_gen_fianzas IS
      CURSOR c_fianzas IS
         SELECT a.nro_cuenta, a.cod_oficina, a.cod_moneda, a.cod_modulo, a.cod_modalidad, a.monto, a.fec_concesion,
                'CX_FIANZAS' tabla, a.fec_vencimiento, b.cod_persona
           FROM cx_fianzas a, ge_est_cuentas g, ge_cta_clientes b
          WHERE a.nro_cuenta = b.nro_cuenta
            AND b.relacion = 'P'
            AND a.cod_modulo = g.cod_modulo
            AND a.cod_modalidad = g.cod_modalidad
            AND a.estado = g.estado
            AND a.fec_solicitud BETWEEN v_fec_inicio AND v_fec_fin
            AND g.activo = 'S'
            AND a.cod_modalidad = 88
            AND a.estado = 'A';

      v_rub_contable      cb_rubros.cod_rubro%TYPE;
      v_cod_persona       ba_personas.cod_persona%TYPE;
      v_cod_rub_economico sb_crc_operaciones_det.cod_rub_economico%TYPE;
      rg_gcope            sb_crc_operaciones_det%ROWTYPE;
   BEGIN
      rg_gcope.nom_referencia := 'OPERACION';
      rg_gcope.nro_formulario := '001';
      FOR i IN c_fianzas LOOP
         v_rub_contable                := IT.pas_cri.fu_obt_cod_rubro(i.nro_cuenta,null,null, 874, null,null,null,null,1, 'D',null,null,null,null,null,null,null);
         rg_gcope.tip_operacion        := substr(v_rub_contable, 6, 3);
         rg_gcope.cta_con_cap_original := v_rub_contable;
         rg_gcope.cod_persona          := i.cod_persona;
         rg_gcope.fecha                := v_fec_fin;
         rg_gcope.cod_modulo           := i.cod_modulo;
         rg_gcope.cod_oficina          := i.cod_oficina;
         rg_gcope.nro_operacion        := i.nro_cuenta;
         rg_gcope.cod_moneda           := fu_obt_mon_iso(i.cod_moneda);
         rg_gcope.fec_operacion        := i.fec_concesion;
         rg_gcope.mto_ori_capital      := i.monto;
         rg_gcope.nro_cuota            := 0;
         rg_gcope.mto_lin_credito      := 0;
         rg_gcope.cta_con_int_original := NULL;
         rg_gcope.fec_pri_vencimiento  := i.fec_vencimiento;
         rg_gcope.mto_ori_interes      := 0;
         rg_gcope.tas_nominal          := 0;
         v_cod_persona                 := fug_obt_cli_principal(i.nro_cuenta);
         rg_gcope.cod_rub_primario     := fu_obt_rub_primario(v_cod_persona);
         v_cod_rub_economico           := fu_obt_rub_economico(i.nro_cuenta, i.tabla);
         rg_gcope.cod_rub_economico    := fu_obt_cod_bcp(v_cod_rub_economico);
         rg_gcope.cod_departamento     := fu_obt_ref_bco_central(v_cod_persona);
         IF trim(rg_gcope.cod_departamento) IS NULL THEN
            rg_gcope.cod_departamento := 'B0';
         END IF;
         rg_gcope.dia_plazo            := i.fec_vencimiento - i.fec_concesion;
         IF fu_pue_env_bcp(rg_gcope.tip_operacion) = 'S' THEN
            v_nro_registro        := v_nro_registro + 1;
            rg_gcope.nro_registro := v_nro_registro;
            --- Inserta Operaciones
            lp_ins_crc_operaciones(rg_gcope);
         ELSE
            rg_gcope.nro_registro := null;
            pr_ins_crc_ope_no_enviados(rg_gcope);
         END IF;
      END LOOP;
   END;

   -- Procedimiento que contiene los datos exigidos para el modulo de Mesa de Dinero


   PROCEDURE pr_crc_gen_mes_dinero IS

      v_cod_rub_capital   cb_sal_inventarios.cod_rubro%TYPE;
      v_cod_rub_interes   cb_sal_inventarios.cod_rubro%TYPE;
      v_cod_transaccion   ge_transacciones.cod_transaccion%TYPE;
      v_cod_tra_interes   ge_transacciones.cod_transaccion%TYPE;
      v_cod_persona       ba_personas.cod_persona%TYPE;
      v_cod_rub_economico sb_crc_operaciones_det.cod_rub_economico%TYPE;
      rg_gcope            sb_crc_operaciones_det%ROWTYPE;
      v_tip_movimiento    VARCHAR2(01);
      --
      CURSOR c_mesa IS
         SELECT a.cod_modulo, a.cod_modalidad, a.cod_oficina, a.nro_cuenta, c.cod_sec_contable, c.cod_tip_deudor,
                c.residente, a.cod_moneda, a.estado,
                fug_obt_plz_contable(nvl(a.fec_vencimiento - a.fec_inicio, 0)) cod_plazo, a.monto,
                nvl(a.cod_sit_contable, '10000000') cod_sit_contable, a.fec_ven_repo, b.cod_persona, a.tip_calculo,
                a.mer_secundario, a.mto_interes, a.val_tasa, a.cantidad,
                decode(a.fec_vencimiento - a.fec_inicio, 0, 1, a.fec_vencimiento - a.fec_inicio) dia_plazo, a.fec_inicio,
                a.fec_vencimiento
           FROM ge_clientes c, ge_cta_clientes b, md_cta_documentos a
          WHERE b.nro_cuenta = a.nro_cuenta
            AND b.relacion = 'P'
            AND c.cod_persona = b.cod_persona
            AND a.estado NOT IN ('N', 'S')
            AND ((a.fec_inicio BETWEEN v_fec_inicio AND v_fec_fin and a.cod_modalidad not in (select val_parametro from ge_par_dinamicos where parametro = 'MOD_CON_FEC_MESA'))--fieldesk-3134
                 or ((a.fec_inicio ) BETWEEN (v_fec_inicio - 15) AND v_fec_fin and a.cod_modalidad in (select val_parametro from ge_par_dinamicos where parametro = 'MOD_CON_FEC_MESA'))) --fieldesk-3134
            AND NOT EXISTS (SELECT 1
                   FROM ge_par_dinamicos d
                  WHERE d.parametro = 'SIB_CRC_MAD_EXC_ARCHIVO'
                    AND d.cod_modalidad = a.cod_modalidad
                    AND nvl(d.val_parametro, 'N') = 'S')
            AND NOT EXISTS (SELECT 1
                   FROM sb_crc_operaciones_det c
                  WHERE c.nro_operacion = a.nro_cuenta);

   BEGIN
      rg_gcope.nom_referencia := 'OPERACION';
      rg_gcope.nro_formulario := '001';

      FOR i IN c_mesa LOOP
         v_cod_rub_capital := pab_asi.fu_obt_rub_contable(i.nro_cuenta, 'C');
         IF v_cod_rub_capital IS NULL THEN

            v_tip_movimiento  := 'D';
            v_cod_transaccion := 711;
            -- para capital
            IF i.cod_modalidad IN (100, 101, 102, 105, 125, 129, 132, 123, 104, 124) --bonos tesoro, municipalidad, cc, lrm,bonos privados
             THEN
               v_tip_movimiento := 'D';
               IF i.cod_sit_contable = '10000001' THEN
                  v_cod_transaccion := 805;
               ELSE
                  v_cod_transaccion := 711;
               END IF;
            ELSIF i.cod_modalidad IN (101, 102, 129, 132, 123) THEN
               v_tip_movimiento  := 'C';
               v_cod_transaccion := 811;
            ELSIF i.cod_modalidad IN (117, 145) THEN
               --prestamos afd
               v_tip_movimiento  := 'C';
               v_cod_transaccion := 801;
            ELSIF i.cod_modalidad IN (109, 118, 112, 126, 144, 106, 110, 116) THEN
               --prestamos recibidos,colocaciones, bonos afd
               v_tip_movimiento  := 'D';
               v_cod_transaccion := 711;
            END IF;
            v_cod_rub_capital := fu_obt_cod_rubro(i.nro_cuenta,null,null, v_cod_transaccion, null,null,null,null,to_char(i.cod_plazo), v_tip_movimiento,null,i.estado,null,null,null,null,null);
         END IF;

         -- para interes
         v_cod_rub_interes := pab_asi.fu_obt_rub_contable(i.nro_cuenta, 'I');
         IF v_cod_rub_interes IS NULL THEN
            v_tip_movimiento  := 'D';
            v_cod_tra_interes := 719;

            IF (i.cod_modalidad IN (100, 101, 102, 105, 125, 129, 132, 123)) THEN
               --documentos originales en estado normal
               v_tip_movimiento := 'D';
               IF (i.cod_sit_contable = '10000001') THEN
                  v_cod_tra_interes := 813;
               ELSE
                  v_cod_tra_interes := 719;
               END IF;
            ELSIF (i.cod_modalidad IN (104, 124)) THEN
               --bonos privados
               v_tip_movimiento := 'D';
               IF (i.cod_sit_contable = '10000001') THEN
                  v_cod_tra_interes := 811;
               ELSE
                  v_cod_tra_interes := 719;
               END IF;
            ELSIF (i.cod_modalidad = 106) THEN
               --bonos afd
               v_tip_movimiento  := 'D';
               v_cod_tra_interes := 719;
            END IF;
            v_cod_rub_interes := fu_obt_cod_rubro(i.nro_cuenta,null,null, v_cod_tra_interes, null,null,null,null,to_char(i.cod_plazo), v_tip_movimiento,null,i.estado,null,null,null,null,null);
         END IF;
         SELECT MIN(fec_vencimiento), nvl(SUM(mto_interes), 0)
           INTO rg_gcope.fec_pri_vencimiento, rg_gcope.mto_ori_interes
           FROM md_doc_detalles
          WHERE nro_cuenta = i.nro_cuenta
            AND nro_cuota > 0;
         IF rg_gcope.fec_pri_vencimiento IS NULL THEN
            rg_gcope.fec_pri_vencimiento := i.fec_vencimiento;
         END IF;
         --
         rg_gcope.tip_operacion        := substr(v_cod_rub_capital, 6, 3);
         rg_gcope.cta_con_cap_original := v_cod_rub_capital;
         rg_gcope.cod_persona          := i.cod_persona;
         rg_gcope.fecha                := v_fec_fin;
         rg_gcope.cod_modulo           := i.cod_modulo;
         rg_gcope.cod_oficina          := i.cod_oficina;
         rg_gcope.nro_operacion        := i.nro_cuenta;
         rg_gcope.cod_moneda           := fu_obt_mon_iso(i.cod_moneda);
         rg_gcope.fec_operacion        := i.fec_inicio;
         rg_gcope.mto_ori_capital      := i.monto;
         rg_gcope.nro_cuota            := i.cantidad;
         rg_gcope.mto_lin_credito      := 0;
         rg_gcope.cta_con_int_original := v_cod_rub_interes;
         rg_gcope.tas_nominal          := i.val_tasa;
         rg_gcope.dia_plazo            := i.dia_plazo;
         v_cod_persona                 := fug_obt_cli_principal(i.nro_cuenta);
         rg_gcope.cod_rub_primario     := fu_obt_rub_primario(i.cod_persona);
         v_cod_rub_economico           := fu_obt_rub_economico(i.nro_cuenta, 'MD_CTA_DOCUMENTOS');
         rg_gcope.cod_rub_economico    := fu_obt_cod_bcp(v_cod_rub_economico);
         rg_gcope.cod_departamento     := fu_obt_ref_bco_central(i.cod_persona);
         IF trim(rg_gcope.cod_departamento) IS NULL THEN
               rg_gcope.cod_departamento := 'B0';
         END IF;
         ---
         IF fu_pue_env_bcp(rg_gcope.tip_operacion) = 'S' THEN
            v_nro_registro        := v_nro_registro + 1;
            rg_gcope.nro_registro := v_nro_registro;
            --- Inserta Operaciones
            lp_ins_crc_operaciones(rg_gcope);
         ELSE
            rg_gcope.nro_registro := null;
            pr_ins_crc_ope_no_enviados(rg_gcope);
         END IF;
      END LOOP;
   END;

   -- Procedimiento que contiene los datos exigidos para el modulo de Operaciones Vencidas
   PROCEDURE pr_crc_gen_ope_vencidas IS
      CURSOR c_ope_vencidas IS
         SELECT a.nro_cuenta, a.cod_oficina, a.cod_moneda, a.cod_modulo, a.cod_modalidad, a.mto_origen, a.fec_apertura,
                a.sal_total, a.val_tasa, nvl(a.dia_atraso, 0) dia_atraso, 'C' situacion, b.cod_persona, a.estado,
                a.est_batch
           FROM ov_cta_vencidas a, ge_est_cuentas g, ge_cta_clientes b
          WHERE a.nro_cuenta = b.nro_cuenta
            AND b.relacion = 'P'
            AND a.cod_modulo = g.cod_modulo
            AND a.cod_modalidad = g.cod_modalidad
            AND a.estado = g.estado
          --  AND a.estado <> 'I'
            AND a.fec_apertura BETWEEN v_fec_inicio AND v_fec_fin
            AND NOT EXISTS (SELECT 1
                              FROM sb_crc_operaciones_det c
                             WHERE c.nro_operacion = a.nro_cuenta);

      v_rub_contable       cb_rubros.cod_rubro%TYPE;
      v_cod_rub_economico  sb_crc_operaciones_det.cod_rub_economico%TYPE;
      v_fec_pas_incobrable sb_crc_operaciones_det.fecha%TYPE;
      rg_gcope             sb_crc_operaciones_det%ROWTYPE;
   BEGIN
      rg_gcope.nom_referencia := 'OPERACION';
      rg_gcope.nro_formulario := '001';
      FOR i IN c_ope_vencidas LOOP
         v_rub_contable                := pab_asi.fu_obt_rub_contable(i.nro_cuenta, i.situacion);
         v_fec_pas_incobrable          := to_date(fug_obt_paradicional(i.nro_cuenta, 'PRE_FEC_PAS_INCOBRABLE'),
                                                  'dd/mm/yyyy');
         rg_gcope.tip_operacion        := substr(v_rub_contable, 6, 3);
         rg_gcope.cta_con_cap_original := v_rub_contable;
         rg_gcope.cod_persona          := i.cod_persona;
         rg_gcope.fecha                := v_fec_fin;
         rg_gcope.cod_modulo           := i.cod_modulo;
         rg_gcope.cod_oficina          := i.cod_oficina;
         rg_gcope.nro_operacion        := i.nro_cuenta;
         rg_gcope.cod_moneda           := fu_obt_mon_iso(i.cod_moneda);
         rg_gcope.fec_operacion        := i.fec_apertura;
         rg_gcope.fec_pri_vencimiento  := i.fec_apertura + 1;
         rg_gcope.mto_ori_capital      := i.mto_origen;
         rg_gcope.nro_cuota            := 0;
         rg_gcope.mto_lin_credito      := 0;
         rg_gcope.cta_con_int_original := pab_asi.fu_obt_rub_contable(i.nro_cuenta, 'I');
         rg_gcope.tas_nominal          := i.val_tasa;
         IF fu_pue_env_bcp(rg_gcope.tip_operacion) = 'S' THEN
            rg_gcope.dia_plazo       := 0;
            rg_gcope.mto_ori_interes := nvl(i.sal_total, 0) - nvl(i.mto_origen, 0);
            IF nvl(rg_gcope.mto_ori_interes, 0) < 0 THEN
               rg_gcope.mto_ori_interes := 0;
            END IF;
            rg_gcope.cod_rub_primario  := fu_obt_rub_primario(rg_gcope.cod_persona);
            v_cod_rub_economico        := fu_obt_rub_economico(i.nro_cuenta, 'OV_CTA_VENCIDAS');
            rg_gcope.cod_rub_economico := fu_obt_cod_bcp(v_cod_rub_economico);
            rg_gcope.cod_departamento  := fu_obt_ref_bco_central(rg_gcope.cod_persona);
            IF trim(rg_gcope.cod_departamento) IS NULL THEN
               rg_gcope.cod_departamento := 'B0';
            END IF;

            if fu_pue_env_bcp(rg_gcope.tip_operacion) = 'S' then
               IF ((i.estado <> 'I') OR (i.estado = 'I' AND v_fec_pas_incobrable IS NULL) OR
                  (i.est_batch = 'I' AND v_fec_pas_incobrable IS NOT NULL AND
                  ((v_fec_actual - v_fec_pas_incobrable) <= v_crc_can_dia_incobrable))) THEN
                  v_nro_registro        := v_nro_registro + 1;
                  rg_gcope.nro_registro := v_nro_registro;
                  --- Inserta Operaciones
                  lp_ins_crc_operaciones(rg_gcope);
               END IF;
            else
               rg_gcope.nro_registro := null;
               pr_ins_crc_ope_no_enviados(rg_gcope);
            end if;
         END IF;
      END LOOP;
   END;

   PROCEDURE pr_crc_gen_pasivas IS
      CURSOR c_pasivas IS
     SELECT p.nro_cuenta,
             p.cod_oficina,
             p.cod_moneda,
             p.cod_modulo,
             p.cod_modalidad,
             p.sal_contable,
             p.val_tasa,
             b.cod_persona,
             h.fec_apertura fec_apertura,
             h.capital mto_capitaL,
             h.fec_vencimiento - h.fec_apertura plazo ,
             c.cod_sec_contable,
             c.residente,
             c.cod_tip_deudor,
             p.cod_sit_contable,
             h.estado,
             (SELECT MIN(fec_vencimiento) FROM ah_cupones WHERE nro_cuenta = p.nro_cuenta) fec_pri_vencimiento,
             NULL situacion,
             null cod_sub_modalidad,
             h.cod_isin
        FROM ge_cuentas p, ge_cta_clientes b, ge_est_cuentas g ,ah_cta_certificados h , ge_clientes c
       WHERE p.nro_cuenta = b.nro_cuenta
            AND b.relacion = 'P'
            AND p.estado = g.estado
            AND p.cod_modulo = g.cod_modulo
            AND p.cod_modalidad = g.cod_modalidad
            AND h.nro_cuenta = b.nro_cuenta
            AND g.estado <> 'C'
            AND h.estado NOT IN ('A', 'X', 'C','T')
            AND c.cod_persona = b.cod_persona
            AND ((h.fec_apertura BETWEEN v_fec_inicio AND v_fec_fin) OR
                  h.fec_apertura < (SELECT MAX(fecha)
                                          FROM ge_cuentas_nov n
                                         WHERE n.est_anterior = 'A'
                                           AND n.est_actual = 'N'
                                           AND n.nro_cuenta = h.nro_cuenta))
            AND NOT EXISTS (SELECT 1
                   FROM ge_par_dinamicos s
                  WHERE s.parametro = 'SIB_CRC_MAD_EXC_ARCHIVO'
                    AND s.cod_modalidad = h.cod_modalidad
                    AND nvl(s.val_parametro, 'N') = 'S')
                  AND (p.cod_modalidad <> 34 OR h.cod_isin IS NOT NULL)
            AND NOT EXISTS (SELECT 1
                   FROM sb_crc_operaciones_det c
                  WHERE c.nro_operacion IN (p.nro_cuenta, h.cod_isin)
                    AND c.tip_operacion <> substr(v_tip_ope_cup_ven,instr(v_tip_ope_cup_ven,c.tip_operacion),3))
      ------
      union
      -- cda vigentes con cupones vencidos tipo de operacion 138
         SELECT p.nro_cuenta,
                p.cod_oficina,
                p.cod_moneda,
                p.cod_modulo,
                p.cod_modalidad,
                NULL,
                p.val_tasa val_tasa,
                b.cod_persona,
                NULL fec_apertura,
                h.capital mto_capital,
                NULL plazo,
                NULL cod_sec_contable,
                NULL residente,
                NULL cod_tip_deudor,
                null cod_sit_contable,
                h.estado,
                null fec_pri_vencimiento,
                'V' situacion,
                NULL cod_sub_modalidad,
                h.cod_isin
           FROM ge_cuentas p, ge_cta_clientes b, ah_cta_certificados h, ah_cupones c
          WHERE p.nro_cuenta = b.nro_cuenta
            AND b.relacion = 'P'
            AND h.nro_cuenta = b.nro_cuenta
            AND h.estado IN ('N', 'V', 'P')
            AND v_inc_cup_cda = 'S'
            AND (c.estado = 'V' AND pag_cal.fu_obt_fec_habil(c.fec_vencimiento, 1, NULL) BETWEEN v_fec_inicio AND
                v_fec_fin OR (c.estado <> 'V' AND h.estado = 'V'))
            AND c.nro_cuenta = h.nro_cuenta
            AND NOT EXISTS (SELECT 1
                   FROM ge_par_dinamicos s
                  WHERE s.parametro = 'SIB_CRC_MAD_EXC_ARCHIVO'
                    AND s.cod_modalidad = h.cod_modalidad
                    AND nvl(s.val_parametro, 'N') = 'S')
                  AND (p.cod_modalidad <> 34 OR h.cod_isin IS NOT NULL)
            AND NOT EXISTS (SELECT 1
                   FROM sb_crc_operaciones_det r
                  WHERE r.nro_operacion IN (h.nro_cuenta, h.cod_isin)
                    AND r.tip_operacion = substr(v_tip_ope_cup_ven,instr(v_tip_ope_cup_ven,r.tip_operacion),3))
          GROUP BY p.nro_cuenta, p.cod_oficina, p.cod_moneda, p.cod_modulo, p.cod_modalidad,p.val_tasa, b.cod_persona, h.capital,h.estado,
          h.serie, h.nro_certificado, h.cod_isin
          -----
     UNION
      SELECT p.nro_cuenta,
             p.cod_oficina,
             p.cod_moneda,
             p.cod_modulo,
             p.cod_modalidad,
             p.sal_contable,
             p.val_tasa,
             b.cod_persona,
             h.fec_apertura,
             CASE
                WHEN (nvl((nvl(sal_tot_batch, 0) - nvl(sal_blo_batch, 0) - nvl(sal_ret_batch, 0)), 0))
                     < 0 THEN 0
                ELSE nvl(sal_tot_batch, 0) - nvl(sal_blo_batch, 0) - nvl(sal_ret_batch, 0)
             END mto_capital,
             0 plazo,
             c.cod_sec_contable,
             c.residente,
             c.cod_tip_deudor,
             p.cod_sit_contable,
             h.estado,
             h.fec_apertura + 1 fec_pri_vencimiento,
             NULL,
             null,
             NULL cod_isin
        FROM ge_cuentas p, ge_cta_clientes b, ge_est_cuentas g, cc_cta_corrientes h, ge_cuentas_nov v, ge_clientes c
       WHERE p.nro_cuenta = b.nro_cuenta
         AND h.nro_cuenta = b.nro_cuenta
         AND b.relacion = 'P'
         AND p.estado = g.estado
         AND p.cod_modulo = g.cod_modulo
         AND p.cod_modalidad = g.cod_modalidad
         AND c.cod_persona = b.cod_persona
         AND h.estado NOT IN ('A','X','C')
         AND v.nro_cuenta = p.nro_cuenta
         AND v.hora = (SELECT MAX(n.hora) hora
                         FROM ge_cuentas_nov n
                        WHERE n.nro_cuenta = v.nro_cuenta
                          AND (n.est_anterior = 'A'
                          AND n.est_actual = 'N'
                            or (v.est_anterior = 'I'
                                 AND v.est_actual = 'N'))
                          AND n.fecha BETWEEN v_fec_inicio AND v_fec_fin)
         AND (v.est_anterior = 'A' -- A-bierta
            AND v.est_actual = 'N' -- N-ormal
             or (v.est_anterior = 'I' -- A-bierta
               AND v.est_actual = 'N'))--Se deben informar las cuentas que Inactivas que pasan a Normal si a?n no fueron informadas
         AND v.fecha BETWEEN v_fec_inicio AND v_fec_fin
         AND NOT EXISTS (SELECT 1 FROM sb_crc_operaciones_det r
                                 WHERE r.nro_operacion = h.nro_cuenta
                                   AND IT.pas_cri.fu_obt_tip_operacion(r.tip_operacion, 'SIB_CRC_TIP_OPE_CTA_CTE')='S')
     ---CC no generados
     UNION

     SELECT p.nro_cuenta,
             p.cod_oficina,
             p.cod_moneda,
             p.cod_modulo,
             p.cod_modalidad,
             p.sal_contable,
             p.val_tasa,
             b.cod_persona,
             h.fec_apertura,
             CASE
                WHEN (nvl((nvl(sal_tot_batch, 0) - nvl(sal_blo_batch, 0) - nvl(sal_ret_batch, 0)), 0))
                     < 0 THEN 0
                ELSE nvl(sal_tot_batch, 0) - nvl(sal_blo_batch, 0) - nvl(sal_ret_batch, 0)
             END mto_capital,
             0 plazo,
             c.cod_sec_contable,
             c.residente,
             c.cod_tip_deudor,
             p.cod_sit_contable,
             h.estado,
             h.fec_apertura + 1 fec_pri_vencimiento,
             NULL,
             null,
             NULL cod_isin
        FROM ge_cuentas p, ge_cta_clientes b, ge_est_cuentas g, cc_cta_corrientes h, ge_clientes c
       WHERE p.nro_cuenta = b.nro_cuenta
         AND h.nro_cuenta = b.nro_cuenta
         AND b.relacion = 'P'
         AND p.estado = g.estado
         AND p.cod_modulo = g.cod_modulo
         AND p.cod_modalidad = g.cod_modalidad
         AND c.cod_persona = b.cod_persona
         AND h.estado NOT IN ('A','X','C')
         and trunc(h.fec_apertura) between v_fec_fin - 15 AND v_fec_fin
         AND NOT EXISTS (SELECT 1 FROM sb_crc_operaciones_det r
                                 WHERE r.nro_operacion = h.nro_cuenta
                                   AND IT.pas_cri.fu_obt_tip_operacion(r.tip_operacion, 'SIB_CRC_TIP_OPE_CTA_CTE')='S')
     ------
     UNION
      SELECT p.nro_cuenta,
             p.cod_oficina,
             p.cod_moneda,
             p.cod_modulo,
             p.cod_modalidad,
             p.sal_contable,
             p.val_tasa,
             b.cod_persona,
             v.fecha fec_apertura,
             CASE
                WHEN  nvl((nvl(sal_tot_batch, 0) - nvl(sal_blo_batch, 0) - nvl(sal_ret_batch, 0)),0)
                     < 0 THEN 0
                ELSE nvl(sal_tot_batch, 0) - nvl(sal_blo_batch, 0) - nvl(sal_ret_batch, 0)
             END mto_capital,
             0 plazo,
             c.cod_sec_contable,
             c.residente,
             c.cod_tip_deudor,
             p.cod_sit_contable,
             h.estado,
             v.fecha + 1 fec_pri_vencimiento,
             'N',
             h.cod_sub_modalidad,
             NULL cod_isin
        FROM ge_cuentas p, ge_cta_clientes b, ge_est_cuentas g, ah_cta_vistas h, ge_clientes c,
                (SELECT nro_cuenta, MAX(hora), fecha
                    FROM ge_cuentas_nov n
                   WHERE n.est_anterior = 'A'
                     AND n.est_actual = 'N'
                     AND n.fecha BETWEEN v_fec_inicio AND v_fec_fin
                   GROUP BY nro_cuenta, fecha) v
      WHERE p.nro_cuenta = b.nro_cuenta
            AND h.nro_cuenta = b.nro_cuenta
            AND b.relacion = 'P'
            AND p.estado = g.estado
            AND p.cod_modulo = g.cod_modulo
            AND p.cod_modalidad = g.cod_modalidad
            AND c.cod_persona = b.cod_persona
               -- Se informan al fondear
            AND g.activo = 'S'
            AND v.nro_cuenta(+) = p.nro_cuenta
            --AND h.estado NOT IN ('A', 'X', 'C')
            AND h.estado NOT IN ('A', 'X', 'C','I')
            AND (v.fecha BETWEEN v_fec_inicio AND v_fec_fin OR h.fec_apertura BETWEEN v_fec_inicio AND v_fec_fin
            or (h.fec_apertura <= v_fec_fin  and trunc (h.fec_insercion) > to_date(fug_obt_pardinamico('PSB_FEC_INI_ITGF'),'dd/mm/yyyy')))--FIELDESK-13627--ajuste para incluir todas las cuentas con estado correcto, posteriores al inicio de ITGF
            AND NOT EXISTS (SELECT 1
                   FROM sb_crc_operaciones_det r
                  WHERE r.nro_operacion = h.nro_cuenta)
     UNION --- Cuentas Bancarias
      SELECT p.nro_cuenta,
             p.cod_oficina,
             p.cod_moneda,
             p.cod_modulo,
             p.cod_modalidad,
             p.sal_contable,
             p.val_tasa,
             nvl(IT.pas_cri.fu_obt_cod_per_bco(p.nro_cuenta), b.cod_persona) cod_persona,
             h.fec_apertura,
             (CASE
               WHEN nvl((nvl(sal_tot_batch, 0) - nvl(sal_blo_batch, 0) - nvl(sal_ret_batch, 0)), 0) < 0 THEN 0
               ELSE nvl((nvl(sal_tot_batch, 0) - nvl(sal_blo_batch, 0) - nvl(sal_ret_batch, 0)), 0)
             END) mto_capital,
             0 plazo,
             c.cod_sec_contable,
             c.residente,
             c.cod_tip_deudor,
             p.cod_sit_contable,
             h.estado,
             h.fec_apertura fec_pri_vencimiento,
             NULL,
             null,
             NULL cod_isin
        FROM ge_cuentas p, ge_cta_clientes b, ge_est_cuentas g, cc_cta_bancarias h, ge_clientes c
       WHERE p.nro_cuenta = b.nro_cuenta
         AND h.nro_cuenta = b.nro_cuenta
         AND b.relacion = 'P'
         AND p.estado = g.estado
         AND c.cod_persona = b.cod_persona
         AND p.cod_modulo = g.cod_modulo
         AND p.cod_modalidad = g.cod_modalidad
         AND h.fec_apertura BETWEEN v_fec_inicio AND v_fec_fin
         AND NOT EXISTS (SELECT 1
                           FROM ge_par_dinamicos s
                          WHERE s.parametro = 'SIB_CRC_MAD_EXC_ARCHIVO'
                            AND s.cod_modalidad = h.cod_modalidad
                            AND nvl(s.val_parametro, 'N') = 'S')
         AND NOT EXISTS (SELECT 1 FROM sb_crc_operaciones_det c WHERE c.nro_operacion = p.nro_cuenta)
     /*UNION --- CDA Vencidos
      SELECT p.nro_cuenta,
             p.cod_oficina,
             p.cod_moneda,
             p.cod_modulo,
             p.cod_modalidad,
             p.sal_contable,
             p.val_tasa,
             b.cod_persona,
             h.fec_apertura fec_apertura,
             h.capital mto_capitaL,
             0 plazo ,
             c.cod_sec_contable,
             c.residente,
             c.cod_tip_deudor,
             p.cod_sit_contable,
             h.estado,
             u.fec_vencimiento fec_pri_vencimiento,
             i.situacion,
             null
        FROM ge_cuentas p, ge_cta_clientes b, ge_est_cuentas g ,ah_cta_certificados h , ge_clientes c, ah_cupones u, cb_sal_inventarios i, cb_sal_inventarios_det d
       WHERE p.nro_cuenta = b.nro_cuenta
         AND b.relacion = 'P'
         AND p.estado = g.estado
         AND p.cod_modulo = g.cod_modulo
         AND p.cod_modalidad = g.cod_modalidad
         AND h.nro_cuenta = b.nro_cuenta
         AND c.cod_persona = b.cod_persona
         AND h.nro_cuenta = u.nro_cuenta
         AND u.fec_vencimiento BETWEEN :v_fec_inicio -5 AND :v_fec_fin
         AND i.nro_referencia = d.nro_referencia
         and i.tip_saldo = 'C'
         and i.situacion = 'V'
         AND d.nro_cuenta = h.nro_cuenta
         AND NOT EXISTS (SELECT 1
                           FROM ge_par_dinamicos s
                          WHERE s.parametro = 'SIB_CRC_MAD_EXC_ARCHIVO'
                            AND s.cod_modalidad = h.cod_modalidad
                            AND nvl(s.val_parametro, 'N') = 'S')
         AND NOT EXISTS (SELECT distinct 1
                              FROM sb_crc_operaciones_det r
                             WHERE r.nro_operacion = d.nro_cuenta
                               AND r.tip_operacion = substr(i.cod_rubro, 6, 3))*/
     UNION --- Plazo Fijo
      SELECT p.nro_cuenta,
             p.cod_oficina,
             p.cod_moneda,
             p.cod_modulo,
             p.cod_modalidad,
             p.sal_contable,
             p.val_tasa,
             b.cod_persona,
             h.fec_apertura fec_apertura,
             h.capital mto_capitaL,
             h.fec_vencimiento - h.fec_apertura plazo ,
             c.cod_sec_contable,
             c.residente,
             c.cod_tip_deudor,
             p.cod_sit_contable,
             h.estado,
             (SELECT MIN(fec_vencimiento) FROM ah_cupones WHERE nro_cuenta = p.nro_cuenta) fec_pri_vencimiento,
             NULL situacion,
             null,
             NULL cod_isin
        FROM ge_cuentas p, ge_cta_clientes b, ge_est_cuentas g ,ah_cta_plazos h , ge_clientes c
       WHERE p.nro_cuenta = b.nro_cuenta
         AND b.relacion = 'P'
         AND p.estado = g.estado
         AND p.cod_modulo = g.cod_modulo
         AND p.cod_modalidad = g.cod_modalidad
         AND h.nro_cuenta = b.nro_cuenta
         AND g.estado = 'N'
         AND c.cod_persona = b.cod_persona
         AND h.fec_apertura BETWEEN v_fec_inicio AND  v_fec_fin
		 AND instr( v_mad_aho_plazo,','||p.cod_modalidad || ',') > 0
        /* AND EXISTS ( SELECT 0
                        FROM ah_cupones a
                       WHERE a.nro_cuenta = h.nro_cuenta )*/
         AND NOT EXISTS (SELECT 1
                           FROM ge_par_dinamicos s
                          WHERE s.parametro = 'SIB_CRC_MAD_EXC_ARCHIVO'
                            AND s.cod_modalidad = h.cod_modalidad
                            AND nvl(s.val_parametro, 'N') = 'S')
         AND NOT EXISTS (SELECT 1 FROM sb_crc_operaciones_det r WHERE r.nro_operacion = h.nro_cuenta)
     UNION -- Ahorro Programado
      SELECT p.nro_cuenta,
             p.cod_oficina,
             p.cod_moneda,
             p.cod_modulo,
             p.cod_modalidad,
             p.sal_contable,
             p.val_tasa,
             b.cod_persona,
             v.fecha fec_apertura,
             h.capital mto_capital,
             h.fec_vencimiento - h.fec_apertura plazo,
             c.cod_sec_contable,
             c.residente,
             c.cod_tip_deudor,
             p.cod_sit_contable,
             h.estado,
             v.fecha + 1 fec_pri_vencimiento,
             NULL situacion,
             null,
             NULL cod_isin
        FROM ge_cuentas p, ge_cta_clientes b, ge_est_cuentas g, ah_cta_plazos h , ge_cuentas_nov v, ge_clientes c
       WHERE p.nro_cuenta = b.nro_cuenta
         AND h.nro_cuenta = b.nro_cuenta
         AND b.relacion = 'P'
         AND p.estado = g.estado
         AND p.cod_modulo = g.cod_modulo
         AND p.cod_modalidad = g.cod_modalidad
         AND c.cod_persona = b.cod_persona
         AND v.nro_cuenta = p.nro_cuenta
         AND v.est_anterior = 'A' -- A-bierta
         AND v.est_actual = 'N' -- N-ormal--
         AND v.fecha BETWEEN v_fec_inicio AND v_fec_fin
         AND EXISTS ( SELECT 0
                        FROM ah_pro_cuotas a
                       WHERE a.nro_cuenta = h.nro_cuenta )
         AND NOT EXISTS (SELECT 1 FROM sb_crc_operaciones_det r WHERE r.nro_operacion = h.nro_cuenta);

         v_rub_contable      cb_rubros.cod_rubro%TYPE;
         v_cod_rub_economico sb_crc_operaciones_det.cod_rub_economico%TYPE;
         rg_gcope            sb_crc_operaciones_det%ROWTYPE;
         v_cod_transaccion   ge_transacciones.cod_transaccion%TYPE;
         v_tip_cuenta        ge_tip_asientos.tip_cuenta%type;
         v_cod_isin          ah_cta_certificados.cod_isin%TYPE;
   BEGIN
      rg_gcope.nom_referencia := 'OPERACION';
      rg_gcope.nro_formulario := '001';
      FOR i IN c_pasivas LOOP
         v_cod_isin := i.cod_isin;
         v_cod_transaccion := 602;
         v_tip_cuenta := null;
         IF i.cod_modalidad IN (31, 33, 34, 37, 38, 41) THEN
            v_tip_saldo := 'C';
            IF i.situacion = 'V' THEN
               v_cod_transaccion := 604;
            END IF;
         ELSE
           v_tip_saldo := 'B';
         END IF;
         v_rub_contable                := pab_asi.fu_obt_rub_contable(i.nro_cuenta, v_tip_saldo, i.situacion);
         IF v_rub_contable IS NULL THEN
            if i.cod_modulo = 3 and i.cod_modalidad = 31 then
              begin
                v_tip_cuenta := fue_obt_val_max_refcodes('TIP_CTA_SUB_MOD_CONTABLE',trim(i.cod_modulo)||i.cod_modalidad||i.cod_sub_modalidad);
              exception
                when others then
                   v_tip_cuenta := null;
              end;
            end if;
            v_rub_contable := IT.pas_cri.fu_obt_cod_rubro(i.nro_cuenta, i.cod_modulo, i.cod_modalidad, v_cod_transaccion,
                                                 i.cod_moneda, i.cod_sec_contable, i.cod_tip_deudor, i.residente, NULL,
                                                 'C', i.cod_sit_contable, i.estado, NULL, NULL, NULL, v_tip_cuenta);
         END IF;
         rg_gcope.tip_operacion        := substr(v_rub_contable, 6, 3);
         rg_gcope.cta_con_cap_original := v_rub_contable;
         IF fu_pue_env_bcp(rg_gcope.tip_operacion) = 'S' THEN
            rg_gcope.cod_persona      := i.cod_persona;
            rg_gcope.fecha            := v_fec_fin;
            rg_gcope.cod_oficina      := i.cod_oficina;
            rg_gcope.cod_modulo       := i.cod_modulo;
            rg_gcope.nro_operacion    := CASE
                                             WHEN i.cod_modalidad = 34 THEN v_cod_isin
                                             ELSE i.nro_cuenta
                                          END;
            rg_gcope.cod_moneda       := fu_obt_mon_iso(i.cod_moneda);
            rg_gcope.fec_operacion    := nvl(i.fec_apertura,v_fec_fin);
            rg_gcope.fec_pri_vencimiento  := nvl(i.fec_pri_vencimiento,rg_gcope.fec_operacion +1);
            rg_gcope.mto_ori_capital  := i.mto_capital;
            IF i.val_tasa IS NULL AND substr(rg_gcope.cta_con_cap_original,6,5) = '13804' THEN
                    BEGIN
                        -- Busco cuenta credito
                        SELECT A.nro_cta_credito
                          INTO v_cta_credito
                          FROM ah_cta_certificados A
                          JOIN ah_cta_vistas B ON A.nro_cta_credito = B.nro_cuenta
                         WHERE A.nro_cuenta = i.nro_cuenta;

                        -- tiene cuenta credito que es ahorro vista
                        rg_gcope.tas_nominal := fus_obt_tas_efectiva(v_cta_credito);


                    EXCEPTION
                        WHEN OTHERS THEN
                           rg_gcope.tas_nominal := NULL;
                    END;

                if rg_gcope.tas_nominal is null then
                  BEGIN
                               select tas_interes
                                 into v_tas_minima
                                 from cr_piz_plazos
                                where cod_modalidad = 31
                                  AND COD_SUB_MODALIDAD = 1
                                  AND TIP_CAPITALIZACION = 1
                                  AND COD_MONEDA IN (i.cod_moneda,
                                                    (SELECT cod_moneda FROM ba_monedas WHERE cod_mon_iso = i.cod_moneda)
                                                );
                                rg_gcope.tas_nominal := v_tas_minima;
                   EXCEPTION
                     WHEN OTHERS THEN
                       rg_gcope.tas_nominal := NULL;
                   END;
                end if;

            ELSIF i.val_tasa IS NOT NULL THEN

               rg_gcope.tas_nominal   := i.val_tasa;

            ELSE
               pag_cta.pr_obt_cuenta(i.nro_cuenta);
               rg_gcope.tas_nominal   := pag_cta.g_ctas.val_tasa;
            END IF;
            rg_gcope.cod_rub_primario := fu_obt_rub_primario(i.cod_persona);
            v_cod_rub_economico       := fu_obt_rub_primario(i.cod_persona);
            rg_gcope.cod_rub_economico:= fu_obt_cod_bcp(v_cod_rub_economico);
            rg_gcope.cod_departamento := fu_obt_ref_bco_central(i.cod_persona);
            rg_gcope.dia_plazo        := i.plazo;
            IF i.cod_modulo = 3 THEN
               rg_gcope.mto_ori_interes      := nvl(fu_obt_mto_interes(i.nro_cuenta),0);
               rg_gcope.cta_con_int_original := pab_asi.fu_obt_rub_contable(i.nro_cuenta, 'I');
            END IF;
            v_nro_registro            := v_nro_registro + 1;
            rg_gcope.nro_registro     := v_nro_registro;
            --- Inserta Operaciones
            lp_ins_crc_operaciones(rg_gcope);

         END IF;
      END LOOP;
   END;
   PROCEDURE pr_crc_gen_cta_basica IS
      CURSOR c_pasivas IS
      SELECT p.nro_cuenta,
             p.cod_oficina,
             p.cod_moneda,
             p.cod_modulo,
             p.cod_modalidad,
             --p.sal_contable,
             p.val_tasa,
             b.cod_persona,
             v.fecha,
             SUM(MONTO) mto_capital,
             0 plazo,
             c.cod_sec_contable,
             c.residente,
             c.cod_tip_deudor,
             p.cod_sit_contable,
             h.estado,
             v.fecha + 1 fec_pri_vencimiento,
             'N' situacion,
             h.cod_sub_modalidad
        FROM ge_cuentas p, ge_cta_clientes b, ge_est_cuentas g ,ah_cta_vistas h , ah_movimientos_his v,
             ge_clientes c, ge_transacciones tr
       WHERE p.nro_cuenta = b.nro_cuenta
         AND h.nro_cuenta = b.nro_cuenta
         AND b.relacion = 'P'
         AND p.estado = g.estado
         AND p.cod_modulo = g.cod_modulo
         AND p.cod_modalidad = g.cod_modalidad
         AND c.cod_persona = b.cod_persona
         AND v.nro_cuenta = p.nro_cuenta
         AND v.fecha BETWEEN v_fec_inicio AND v_fec_fin
         AND v.reversado <> 'S'
         AND v.nro_cuenta = h.nro_cuenta
         and h.cod_sub_modalidad = 26
         and v.cod_modulo = tr.cod_modulo
         and v.cod_modalidad = tr.cod_modalidad
         and v.cod_transaccion = tr.cod_transaccion
         and tr.tipo = 'C'
         and not exists (select 1 from ge_gru_transacciones_det t
                          where t.cod_gru_transaccion = 92
                            and t.cod_modulo = v.cod_mod_padre
                            and t.cod_modalidad = v.cod_mad_padre
                            and t.cod_transaccion = v.Cod_Tra_Padre)
         and not exists(select * from sb_crc_mov_cta_basica cb
                         where cb.nro_operacion = p.nro_cuenta
                         and cb.cod_oficina = p.cod_oficina)

         GROUP BY p.nro_cuenta,
             p.cod_oficina,
             p.cod_moneda,
             p.cod_modulo,
             p.cod_modalidad,
             p.sal_contable,
             p.val_tasa,
             b.cod_persona,
             v.fecha,
             c.cod_sec_contable,
             c.residente,
             c.cod_tip_deudor,
             p.cod_sit_contable,
             h.estado,
             h.cod_sub_modalidad
        having sum(monto) > 0;


         v_rub_contable      cb_rubros.cod_rubro%TYPE;
         v_cod_rub_economico sb_crc_operaciones_det.cod_rub_economico%TYPE;
         rg_gcope            SB_CRC_MOV_CTA_BASICA%ROWTYPE;
         v_cod_transaccion   ge_transacciones.cod_transaccion%TYPE;
         v_tip_cuenta        ge_tip_asientos.tip_cuenta%type;
   BEGIN
      rg_gcope.nom_referencia := 'CTA BASICA';
      rg_gcope.nro_formulario := '001';
      FOR i IN c_pasivas LOOP
         v_cod_transaccion := 602;
         v_tip_cuenta := null;
         v_tip_saldo := 'C';

         v_rub_contable                := pab_asi.fu_obt_rub_contable(i.nro_cuenta, v_tip_saldo, i.situacion);
         IF v_rub_contable IS NULL THEN
            if i.cod_modulo = 3 and i.cod_modalidad = 31 then
              begin
                v_tip_cuenta := fue_obt_val_max_refcodes('TIP_CTA_SUB_MOD_CONTABLE',trim(i.cod_modulo)||i.cod_modalidad||i.cod_sub_modalidad);
              exception
                when others then
                   v_tip_cuenta := null;
              end;
            end if;
            v_rub_contable := IT.pas_cri.fu_obt_cod_rubro(i.nro_cuenta, i.cod_modulo, i.cod_modalidad, v_cod_transaccion,
                                                 i.cod_moneda, i.cod_sec_contable, i.cod_tip_deudor, i.residente, NULL,
                                                 'C', i.cod_sit_contable, i.estado, NULL, NULL, NULL, v_tip_cuenta);
         END IF;
         rg_gcope.tip_operacion        := substr(v_rub_contable, 6, 3);
         rg_gcope.cta_con_cap_original := v_rub_contable;
         IF fu_pue_env_bcp(rg_gcope.tip_operacion) = 'S' THEN
            rg_gcope.cod_persona      := i.cod_persona;
            rg_gcope.fecha            := v_fec_fin;
            rg_gcope.cod_oficina      := i.cod_oficina;
            rg_gcope.cod_modulo       := i.cod_modulo;
            rg_gcope.nro_operacion    := i.nro_cuenta;
            rg_gcope.cod_moneda       := fu_obt_mon_iso(i.cod_moneda);
            rg_gcope.fec_operacion    := i.fecha;
            rg_gcope.fec_pri_vencimiento  := i.fec_pri_vencimiento;
            rg_gcope.mto_ori_capital  := i.mto_capital;
            IF i.val_tasa IS NOT NULL THEN
               rg_gcope.tas_nominal   := i.val_tasa;
            ELSE
               pag_cta.pr_obt_cuenta(i.nro_cuenta);
               rg_gcope.tas_nominal   := pag_cta.g_ctas.val_tasa;
            END IF;
            rg_gcope.cod_rub_primario := fu_obt_rub_primario(i.cod_persona);
            v_cod_rub_economico       := fu_obt_rub_primario(i.cod_persona);
            rg_gcope.cod_rub_economico:= fu_obt_cod_bcp(v_cod_rub_economico);
            rg_gcope.cod_departamento := fu_obt_ref_bco_central(i.cod_persona);
            rg_gcope.dia_plazo        := i.plazo;
            IF i.cod_modulo = 3 THEN
               rg_gcope.mto_ori_interes      := nvl(fu_obt_mto_interes(i.nro_cuenta),0);
               rg_gcope.cta_con_int_original := pab_asi.fu_obt_rub_contable(i.nro_cuenta, 'I');
            END IF;
            v_nro_registro            := v_nro_registro + 1;
            rg_gcope.nro_registro     := v_nro_registro;
            --- Inserta los movimientos de cuenta basica
            lp_ins_crc_ope_cta_basica(rg_gcope);
         END IF;
      END LOOP;
   END;

      PROCEDURE lp_obt_mto_prev_descuento
      (
         p_mto_prevision    IN ge_cla_operaciones.tot_prevision%TYPE,
         p_sal_capital  IN sb_crc_saldos_det.sal_capital%TYPE,
         p_sal_prevision OUT sb_crc_saldos_det.sal_capital%TYPE,
         p_sal_tot_provisionado IN ge_cla_operaciones.tot_prevision%TYPE
      ) IS

      BEGIN
        IF p_mto_prevision  > 0 THEN
           --v_tot_monto := p_mto_con_acuerdo + p_mto_sin_acuerdo;
           --prevision*deuda/total_deuda

           p_sal_prevision := ROUND(((p_mto_prevision * p_sal_capital)/p_sal_tot_provisionado), 2);
         ELSE
           p_sal_prevision:=0;
         END IF;

      END;
    PROCEDURE pr_crc_gen_pignorados IS
      CURSOR c_pignorados IS
      SELECT p.nro_cuenta,
             p.cod_oficina,
             p.cod_moneda,
             p.cod_modulo,
             p.cod_modalidad,
             p.sal_contable,
             p.val_tasa,
             b.cod_persona,
             h.fec_inicio fec_apertura,
             h.monto mto_capital,
             0 plazo,
             c.cod_sec_contable,
             c.residente,
             c.cod_tip_deudor,
             p.cod_sit_contable,
             p.estado,
             h.fec_inicio + 1 fec_pri_vencimiento,
             hc.cod_isin
        FROM ge_cuentas p, ge_cta_clientes b, ge_bloqueos h , ge_clientes c, cb_sal_inventarios i, cb_sal_inventarios_det d,
             ah_cta_certificados hc
       WHERE p.nro_cuenta = b.nro_cuenta
         AND h.nro_cuenta = b.nro_cuenta
         AND hc.nro_cuenta(+) = p.nro_cuenta
         AND hc.cod_modalidad(+) = 34
         AND (p.cod_modalidad <> 34 OR hc.cod_isin IS NOT NULL)
         AND b.relacion = 'P'
         AND c.cod_persona = b.cod_persona
         AND h.fec_inicio BETWEEN v_fec_inicio AND v_fec_fin
         AND h.fec_inicio = ( SELECT MIN(b.fec_inicio)
                                FROM ge_bloqueos b
                               WHERE b.nro_cuenta = h.nro_cuenta
                                 AND b.cod_causa = fug_obt_pardinamico('COD_CAU_BLO_GARAN' ))
         AND h.nro_documento = ( SELECT MIN(nro_documento)
                                   FROM ge_bloqueos g
                                  WHERE g.fec_inicio = h.fec_inicio
                                    AND g.nro_cuenta = h.nro_cuenta
                                    AND g.cod_causa = fug_obt_pardinamico('COD_CAU_BLO_GARAN'))
         AND h.monto > 0
         AND h.cod_causa = fug_obt_pardinamico('COD_CAU_BLO_GARAN')
         and i.nro_referencia = d.nro_referencia
         and i.tip_saldo = 'P'
         and d.nro_cuenta = h.nro_cuenta
         AND NOT EXISTS (SELECT distinct 1
                              FROM sb_crc_operaciones_det r
                             WHERE r.nro_operacion IN (d.nro_cuenta, hc.cod_isin)
                               AND r.tip_operacion = substr(i.cod_rubro, 6, 3))
         AND fu_obt_tip_operacion(substr(i.cod_rubro,6,3), 'SIB_CRC_TIP_OPE_PIGNORADO') = 'S';

         v_rub_contable      cb_rubros.cod_rubro%TYPE;
         v_cod_rub_economico sb_crc_operaciones_det.cod_rub_economico%TYPE;
         v_cod_transaccion   ge_transacciones.cod_transaccion%TYPE;
         rg_gcope            sb_crc_operaciones_det%ROWTYPE;
   BEGIN
      rg_gcope.nom_referencia := 'OPERACION';
      rg_gcope.nro_formulario := '001';
      FOR i IN c_pignorados LOOP
         v_tip_saldo := 'P';
         v_rub_contable := pab_asi.fu_obt_rub_contable(i.nro_cuenta, v_tip_saldo);
         IF v_rub_contable IS NULL THEN
            IF i.cod_modalidad IN (33, 34, 37, 38) THEN
               v_cod_transaccion := 603;
            ELSE
               v_cod_transaccion := 2604;
            END IF;
            v_rub_contable := IT.pas_cri.fu_obt_cod_rubro(i.nro_cuenta, i.cod_modulo, i.cod_modalidad, v_cod_transaccion,
                                                       i.cod_moneda, i.cod_sec_contable, i.cod_tip_deudor, i.residente,
                                                       NULL, 'C', i.cod_sit_contable, i.estado, NULL, NULL, NULL, NULL);
         END IF;
         rg_gcope.tip_operacion        := substr(v_rub_contable, 6, 3);
         rg_gcope.cta_con_cap_original := v_rub_contable;
         IF fu_pue_env_bcp(rg_gcope.tip_operacion) = 'S' THEN
            rg_gcope.cod_persona      := i.cod_persona;
            rg_gcope.fecha            := v_fec_fin;
            rg_gcope.cod_oficina      := i.cod_oficina;
            rg_gcope.cod_modulo       := i.cod_modulo;
            rg_gcope.nro_operacion    := CASE
                                             WHEN i.cod_modalidad = 34 THEN i.cod_isin
                                             ELSE i.nro_cuenta
                                          END;
            rg_gcope.cod_moneda       := fu_obt_mon_iso(i.cod_moneda);
            rg_gcope.fec_operacion    := i.fec_apertura;
            rg_gcope.fec_pri_vencimiento  := i.fec_pri_vencimiento;
            rg_gcope.mto_ori_capital  := i.mto_capital;
            IF i.val_tasa IS NOT NULL THEN
               rg_gcope.tas_nominal   := i.val_tasa;
            ELSE
               pag_cta.pr_obt_cuenta(i.nro_cuenta);
               rg_gcope.tas_nominal   := pag_cta.g_ctas.val_tasa;
            END IF;
            rg_gcope.cod_rub_primario := fu_obt_rub_primario(i.cod_persona);
            v_cod_rub_economico       := fu_obt_rub_primario(i.cod_persona);
            rg_gcope.cod_rub_economico:= fu_obt_cod_bcp(v_cod_rub_economico);
            rg_gcope.cod_departamento := fu_obt_ref_bco_central(i.cod_persona);
            rg_gcope.dia_plazo        := i.plazo;
            rg_gcope.mto_ori_interes  := 0;
            rg_gcope.cta_con_int_original := NULL;
            v_nro_registro            := v_nro_registro + 1;
            rg_gcope.nro_registro     := v_nro_registro;
            --- Inserta Operaciones
            lp_ins_crc_operaciones(rg_gcope);

         END IF;
      END LOOP;
   END;
     PROCEDURE pr_crc_gen_rub_diversos IS
      CURSOR c_rub_diversos IS
      SELECT d.nro_cuenta,
             u.cod_oficina,
             u.cod_moneda,
             sum(d.sal_actual) mto_capital,
             substr(cod_rubro,1,10)||'00000' cod_rubro,
             2 cod_modulo,
             c.cod_persona
        FROM cb_sal_inventarios i, cb_sal_inventarios_det d, ge_cta_clientes c, ge_cuentas u
       WHERE d.nro_referencia = i.nro_referencia
         AND IT.pas_cri.fu_obt_tip_operacion(i.cod_rubro, 'SIB_CRC_RUB_DIV_AUTOMATICO') = 'S'
         AND d.nro_cuenta = c.nro_cuenta
         AND c.relacion = 'P'
         AND u.nro_cuenta = c.nro_cuenta
         AND NOT EXISTS (SELECT distinct 1
                                    FROM sb_crc_operaciones_det r
                                   WHERE r.nro_operacion = d.nro_cuenta
                                     AND r.tip_operacion = substr(i.cod_rubro, 6, 3))
       GROUP BY d.nro_cuenta, u.cod_oficina, u.cod_moneda, c.cod_persona, substr(cod_rubro,1,10)||'00000';

         v_rub_contable      cb_rubros.cod_rubro%TYPE;
         v_cod_rub_economico sb_crc_operaciones_det.cod_rub_economico%TYPE;
         rg_gcope            sb_crc_operaciones_det%ROWTYPE;
   BEGIN
      rg_gcope.nom_referencia := 'OPERACION';
      rg_gcope.nro_formulario := '001';
      FOR i IN c_rub_diversos LOOP
         v_rub_contable := i.cod_rubro;
         rg_gcope.tip_operacion        := substr(v_rub_contable, 6, 3);
         rg_gcope.cta_con_cap_original := v_rub_contable;
         IF fu_pue_env_bcp(rg_gcope.tip_operacion) = 'S' THEN
            rg_gcope.cod_persona      := i.cod_persona;
            rg_gcope.fecha            := v_fec_fin;
            rg_gcope.cod_oficina      := i.cod_oficina;
            rg_gcope.cod_modulo       := i.cod_modulo;
            rg_gcope.nro_operacion    := i.nro_cuenta;
            rg_gcope.cod_moneda       := fu_obt_mon_iso(i.cod_moneda);
            rg_gcope.fec_operacion    := v_fec_fin;
            rg_gcope.fec_pri_vencimiento  := v_fec_fin + 1;
            rg_gcope.mto_ori_capital  := i.mto_capital;
            rg_gcope.tas_nominal      := NULL;
            rg_gcope.cod_rub_primario := fu_obt_rub_primario(i.cod_persona);
            v_cod_rub_economico       := fu_obt_rub_primario(i.cod_persona);
            rg_gcope.cod_rub_economico:= fu_obt_cod_bcp(v_cod_rub_economico);
            rg_gcope.cod_departamento := fu_obt_ref_bco_central(i.cod_persona);
            rg_gcope.dia_plazo        := NULL;
            rg_gcope.mto_ori_interes  := NULL;
            rg_gcope.cta_con_int_original := NULL;
            v_nro_registro            := v_nro_registro + 1;
            rg_gcope.nro_registro     := v_nro_registro;
            --- Inserta Operaciones
            lp_ins_crc_operaciones(rg_gcope);

         END IF;
      END LOOP;
   END;
    PROCEDURE pr_crc_gen_pasivas_compl IS
   --- Inserta las operaciones pasivas complementarias que est?n embargadas y pignoradas del sector financiero
      CURSOR c_embargados IS
      SELECT p.nro_cuenta,
             p.cod_oficina,
             p.cod_moneda,
             p.cod_modulo,
             p.cod_modalidad,
             p.sal_contable,
             p.val_tasa,
             b.cod_persona,
             h.fec_apertura,
             lf_obt_sal_bloqueado(h.nro_cuenta)  mto_capital,
             0 plazo,
             c.cod_sec_contable,
             c.residente,
             c.cod_tip_deudor,
             p.cod_sit_contable,
             h.estado,
             h.fec_apertura + 1 fec_pri_vencimiento,
             '-EMB' sub_tip_ope,
             h.cod_sub_modalidad
        FROM ge_cuentas p, ge_cta_clientes b, ge_est_cuentas g, cc_cta_corrientes h, ge_clientes c
       WHERE p.nro_cuenta = b.nro_cuenta
         AND h.nro_cuenta = b.nro_cuenta
         AND b.relacion = 'P'
         AND p.estado = g.estado
         AND p.cod_modulo = g.cod_modulo
         AND p.cod_modalidad = g.cod_modalidad
         AND c.cod_persona = b.cod_persona
         AND h.estado NOT IN ('A','X','C')
         AND lf_obt_sal_bloqueado(h.nro_cuenta)>0
         AND NOT EXISTS (SELECT distinct 1
                           FROM sb_crc_operaciones_det r
                          WHERE DECODE(INSTR(r.nro_operacion,'-'),0,r.nro_operacion,substr(r.nro_operacion,1,INSTR(r.nro_operacion,'-')-1)) = h.nro_cuenta
                            AND DECODE(INSTR(r.nro_operacion,'-'),0,NULL,substr(r.nro_operacion,INSTR(r.nro_operacion,'-')+1,4 ))='EMB')
  /*  UNION
      SELECT p.nro_cuenta,
             p.cod_oficina,
             p.cod_moneda,
             p.cod_modulo,
             p.cod_modalidad,
             p.sal_contable,
             p.val_tasa,
             b.cod_persona,
             h.fec_apertura,
             lf_obt_sal_bloqueado(h.nro_cuenta)  mto_capital,
             0 plazo,
             c.cod_sec_contable,
             c.residente,
             c.cod_tip_deudor,
             p.cod_sit_contable,
             h.estado,
             h.fec_apertura + 1 fec_pri_vencimiento,
             '-EMB' sub_tip_ope,
             h.cod_sub_modalidad
        FROM ge_cuentas p, ge_cta_clientes b, ge_est_cuentas g, ah_cta_vistas h,  ge_clientes c
       WHERE p.nro_cuenta = b.nro_cuenta
         AND h.nro_cuenta = b.nro_cuenta
         AND b.relacion = 'P'
         AND p.estado = g.estado
         AND p.cod_modulo = g.cod_modulo
         AND p.cod_modalidad = g.cod_modalidad
         AND c.cod_persona = b.cod_persona
         AND h.estado NOT IN ('A','X','C')
         AND lf_obt_sal_bloqueado(h.nro_cuenta)>0
         AND NOT EXISTS (SELECT distinct 1
                           FROM sb_crc_operaciones_det r
                          WHERE DECODE(INSTR(r.nro_operacion,'-'),0,r.nro_operacion,substr(r.nro_operacion,1,INSTR(r.nro_operacion,'-')-1)) = h.nro_cuenta
                            AND DECODE(INSTR(r.nro_operacion,'-'),0,NULL,substr(r.nro_operacion,INSTR(r.nro_operacion,'-')+1,4 ))='EMB')
    UNION
      SELECT p.nro_cuenta,
             p.cod_oficina,
             p.cod_moneda,
             p.cod_modulo,
             p.cod_modalidad,
             p.sal_contable,
             p.val_tasa,
             b.cod_persona,
             h.fec_inicio fec_apertura,
             h.monto mto_capital,
             p.fec_vencimiento-p.fec_apertura plazo,
             c.cod_sec_contable,
             c.residente,
             c.cod_tip_deudor,
             p.cod_sit_contable,
             p.estado,
             h.fec_inicio + 1 fec_pri_vencimiento,
             '-PIG' sub_tip_ope,
             null
        FROM ge_cuentas p, ge_cta_clientes b, ge_bloqueos h , ge_clientes c, cb_sal_inventarios i, cb_sal_inventarios_det d
       WHERE p.nro_cuenta = b.nro_cuenta
         AND h.nro_cuenta = b.nro_cuenta
         AND b.relacion = 'P'
         AND c.cod_persona = b.cod_persona
         AND h.fec_inicio BETWEEN v_fec_inicio AND v_fec_fin
         AND h.fec_inicio = ( SELECT MIN(b.fec_inicio)
                                FROM ge_bloqueos b
                               WHERE b.nro_cuenta = h.nro_cuenta
                                 AND b.cod_causa = fug_obt_pardinamico('COD_CAU_BLO_GARAN'))
         AND h.nro_documento = ( SELECT MIN(nro_documento)
                                   FROM ge_bloqueos g
                                  WHERE g.fec_inicio = h.fec_inicio
                                    AND g.nro_cuenta = h.nro_cuenta
                                    AND g.cod_causa = fug_obt_pardinamico('COD_CAU_BLO_GARAN'))
         AND h.monto > 0
         AND h.cod_causa = fug_obt_pardinamico('COD_CAU_BLO_GARAN')
         AND i.cod_modalidad = 33
         AND i.nro_referencia = d.nro_referencia
         AND i.tip_saldo = 'P'
         AND c.cod_sec_contable ='F'
         AND d.nro_cuenta = h.nro_cuenta
         AND NOT EXISTS (SELECT distinct 1
                           FROM sb_crc_operaciones_det r
                          WHERE DECODE(INSTR(r.nro_operacion,'-'),0,r.nro_operacion,substr(r.nro_operacion,1,INSTR(r.nro_operacion,'-')-1)) = h.nro_cuenta
                            AND DECODE(INSTR(r.nro_operacion,'-'),0,NULL,substr(r.nro_operacion,INSTR(r.nro_operacion,'-')+1,4 ))='PIG')*/;

         v_rub_contable      cb_rubros.cod_rubro%TYPE;
         v_cod_rub_economico sb_crc_operaciones_det.cod_rub_economico%TYPE;
         v_cod_transaccion   ge_transacciones.cod_transaccion%TYPE;
         rg_gcope            sb_crc_operaciones_det%ROWTYPE;
         v_tip_cuenta        ge_tip_asientos.tip_cuenta%type;
   BEGIN
      rg_gcope.nom_referencia := 'OPERACION';
      rg_gcope.nro_formulario := '001';
      FOR i IN c_embargados LOOP

        if i.sub_tip_ope='-EMB' then
             v_tip_saldo := 'Q';
             v_cod_transaccion := 855;

        else
             v_tip_saldo := 'P';
             v_cod_transaccion := 2604;
        END IF;
        v_tip_cuenta := null;
        v_rub_contable := pab_asi.fu_obt_rub_contable(i.nro_cuenta, v_tip_saldo);
        IF v_rub_contable IS NULL THEN
           if i.cod_modulo = 3 and i.cod_modalidad = 31 then
              begin
                v_tip_cuenta := fue_obt_val_max_refcodes('TIP_CTA_SUB_MOD_CONTABLE',trim(i.cod_modulo)||i.cod_modalidad||i.cod_sub_modalidad);
              exception
                when others then
                   v_tip_cuenta := null;
              end;
           end if;
           v_rub_contable := IT.pas_cri.fu_obt_cod_rubro(i.nro_cuenta, i.cod_modulo, i.cod_modalidad, v_cod_transaccion,
                                                           i.cod_moneda, i.cod_sec_contable, i.cod_tip_deudor, i.residente,
                                                           NULL, 'C', i.cod_sit_contable, i.estado, NULL, NULL, NULL, v_tip_cuenta);
        END IF;
         rg_gcope.tip_operacion        := substr(v_rub_contable, 6, 3);
         rg_gcope.cta_con_cap_original := v_rub_contable;
         IF fu_pue_env_bcp(rg_gcope.tip_operacion) = 'S' THEN
            rg_gcope.cod_persona      := i.cod_persona;
            rg_gcope.fecha            := v_fec_fin;
            rg_gcope.cod_oficina      := i.cod_oficina;
            rg_gcope.cod_modulo       := i.cod_modulo;
            rg_gcope.nro_operacion    := i.nro_cuenta||i.sub_tip_ope;
            rg_gcope.cod_moneda       := fu_obt_mon_iso(i.cod_moneda);
            rg_gcope.fec_operacion    := i.fec_apertura;
            rg_gcope.fec_pri_vencimiento  := i.fec_pri_vencimiento;
            rg_gcope.mto_ori_capital  := i.mto_capital;
            IF i.val_tasa IS NOT NULL THEN
               rg_gcope.tas_nominal   := i.val_tasa;
            ELSE
               pag_cta.pr_obt_cuenta(i.nro_cuenta);
               rg_gcope.tas_nominal   := pag_cta.g_ctas.val_tasa;
            END IF;
            rg_gcope.cod_rub_primario := fu_obt_rub_primario(i.cod_persona);
            v_cod_rub_economico       := fu_obt_rub_primario(i.cod_persona);
            rg_gcope.cod_rub_economico:= fu_obt_cod_bcp(v_cod_rub_economico);
            rg_gcope.cod_departamento := fu_obt_ref_bco_central(i.cod_persona);
            rg_gcope.dia_plazo        := i.plazo;
            rg_gcope.mto_ori_interes  := 0;
            rg_gcope.cta_con_int_original := NULL;
            v_nro_registro            := v_nro_registro + 1;
            rg_gcope.nro_registro     := v_nro_registro;
            --- Inserta Operaciones
            lp_ins_crc_operaciones(rg_gcope);

         END IF;
      END LOOP;
   END;
   PROCEDURE pr_crc_gen_che_comprados IS
      v_rub_contable      cb_rubros.cod_rubro%TYPE;
      v_cod_rub_economico sb_crc_operaciones_det.cod_rub_economico%TYPE;
      v_cod_tra_capital   ge_transacciones.cod_transaccion%TYPE;
      rg_gcope            sb_crc_operaciones_det%ROWTYPE;
      v_cod_modulo        ge_modalidades.cod_modulo%TYPE;
      v_cod_modalidad     ge_modalidades.cod_modalidad%TYPE;
      v_cod_moneda        ge_movimientos.cod_moneda%TYPE;
       v_cod_tip_movimiento ge_tip_asientos.tip_movimiento%TYPE;
       v_cod_persona        ba_personas.cod_persona%TYPE;
       CURSOR c_cheques IS
          SELECT a.nro_cheque,
                 a.cod_ofi_origen cod_oficina,
                 b.cod_persona,
                 a.fec_final,
                 a.fec_final - a.fecha plazo,
                 a.fecha,
                 a.monto,
                 a.cod_moneda,
                 a.cod_banco,
                 b.cod_modulo,
                 b.cod_modalidad,
                 'D' tip_movimiento,
                 607 transaccion,
                 a.nro_boleta,
                 a.nro_cuenta nro_operacion,
                 p.nro_documento
            FROM ge_cta_clientes b, cc_che_enviados a, ba_personas p
           WHERE b.nro_cuenta = a.nro_cuenta
             AND a.estado = 'I' -- 'I'ngresados

             and b.cod_persona = p.cod_persona

             AND fup_obt_tip_descuento(b.cod_modalidad) IS NULL
             AND b.relacion = 'P'
             AND NOT EXISTS
           (SELECT 1
                    FROM sb_crc_operaciones_det c
                   WHERE pae_uti.fu_obt_valor(c.nro_operacion, 1) = a.nro_cheque
                     AND tip_operacion = '183')
          UNION
          SELECT a.nro_cheque,
                 a.cod_ofi_origen cod_oficina,
                 b.cod_persona,
                 a.fec_final,
                 a.fec_final - a.fecha plazo,
                 a.fecha,
                 a.monto * -1,
                 a.cod_moneda,
                 a.cod_banco,
                 4, -- b.cod_modulo,
                 43, -- b.cod_modalidad,
                 'C' tip_movimiento,
                 658 transaccion,
                 a.nro_boleta,
                 a.nro_cuenta,
                 p.nro_documento
            FROM ge_cta_clientes b, cc_che_enviados a, ba_personas p
           WHERE b.nro_cuenta = a.nro_cuenta
             AND a.estado = 'E'

             and b.cod_persona = p.cod_persona

             AND a.cta_libradora <> '0'
             AND (a.fecha >=
                 to_date(fug_obt_pardinamico('FEC_IMP_RUB_CHE_COM'), 'dd/mm/yyyy') AND
                 pag_gen.fu_obt_cod_entidad = 2037)
             AND fup_obt_tip_descuento(b.cod_modalidad) = 'C'
             AND b.relacion = 'P'
             AND NOT EXISTS
           (SELECT 1
                    FROM sb_crc_operaciones_det c
                   WHERE pae_uti.fu_obt_valor(c.nro_operacion, 1) = a.nro_cheque
                     AND tip_operacion = '183')
          UNION
          SELECT pr.nro_cheque,
                 pr.cod_ofi_origen,
                 g.cod_persona,
                 pr.fec_final,
                 pr.fec_final - pr.fecha plazo,
                 pr.fecha,
                 pr.monto,
                 pr.cod_moneda,
                 pr.cod_banco,
                 7,
                 71,
                 'D',
                 632,
                 pr.nro_boleta,
                 to_char(g.nro_operacion),
                 p.nro_documento
            FROM cc_che_enviados pr, lc_che_comprados g, ge_cta_clientes a, ba_personas p
           WHERE pr.nro_cheque = g.nro_cheque(+)
             AND pr.cod_banco = g.cod_banco(+)
             AND (pr.fecha >=
                 to_date(fug_obt_pardinamico('FEC_IMP_RUB_CHE_COM'), 'dd/mm/yyyy') AND
                 pag_gen.fu_obt_cod_entidad = 2037)
             AND pr.nro_cuenta IS NULL

             and a.nro_cuenta = pr.nro_cuenta
             and a.cod_persona = p.cod_persona

             AND pr.estado = 'I'
             AND NOT EXISTS
           (SELECT 1
                    FROM sb_crc_operaciones_det c
                   WHERE pae_uti.fu_obt_valor(c.nro_operacion, 1) = pr.nro_cheque
                     AND tip_operacion = '183');

    BEGIN
       rg_gcope.nom_referencia := 'OPERACION';
       rg_gcope.nro_formulario := '001';
       rg_gcope.fecha          := v_fec_fin;
       v_cod_tra_capital       := null;
       v_cod_modulo            := null;
       v_cod_modalidad         := null;
       v_cod_moneda            := null;
       v_cod_tip_movimiento    := null;
       v_cod_persona           := null;
       FOR i IN c_cheques LOOP
          BEGIN
             SELECT DISTINCT cod_transaccion,
                             cod_modulo,
                             cod_modalidad,
                             cod_moneda,
                             cod_persona
               INTO v_cod_tra_capital,
                    v_cod_modulo,
                    v_cod_modalidad,
                    v_cod_moneda,
                    v_cod_persona
               FROM gv_movimientos c
              WHERE c.nro_documento = i.nro_boleta
                AND c.cod_transaccion IN (607, 610, 632, 633, 658)
                AND c.fecha BETWEEN v_fec_inicio AND v_fec_fin;
          EXCEPTION
             WHEN no_data_found THEN
                v_cod_tra_capital    := 607;
                v_cod_modulo         := 6;
                v_cod_modalidad      := 61;
                v_cod_tip_movimiento := 'D';
                v_cod_moneda         := i.cod_moneda;
             WHEN OTHERS THEN
                v_cod_tra_capital    := 607;
                v_cod_modulo         := 6;
                v_cod_modalidad      := 61;
                v_cod_tip_movimiento := 'D';
                v_cod_moneda         := i.cod_moneda;
          END;
          rg_gcope.mto_ori_capital      := i.monto;
          IF v_cod_tra_capital = 632 THEN
             v_cod_tip_movimiento := 'D';
          ELSE
             v_cod_tip_movimiento := i.tip_movimiento;
          END IF;
          v_rub_contable                := fu_obt_cod_rubro(null,v_cod_modulo,v_cod_modalidad, nvl(v_cod_tra_capital,i.transaccion), v_cod_moneda,null,null,null,null, v_cod_tip_movimiento,null,null,null,null,null,null,null);
         IF v_rub_contable IS NULL THEN
            v_rub_contable := pab_asi.fu_obt_rub_contable(i.nro_cheque ,'C');
         END IF;
         rg_gcope.tip_operacion        := substr(v_rub_contable, 6, 3);
         rg_gcope.cta_con_cap_original := v_rub_contable;
         rg_gcope.cod_persona          := v_cod_per_entidad;
         rg_gcope.fecha                := v_fec_fin;
         rg_gcope.cod_oficina          := i.cod_oficina;
         rg_gcope.cod_modulo           := i.cod_modulo;
         ---rg_gcope.nro_operacion        := i.nro_cheque || '#' || i.nro_cheque || '#' || i.cod_banco;
         rg_gcope.nro_operacion        := i.nro_operacion || '#' || i.nro_cheque || '#' || i.nro_documento;
         rg_gcope.cod_moneda           := fu_obt_mon_iso(i.cod_moneda);
         rg_gcope.fec_operacion        := nvl(i.fecha, v_fec_fin);
         rg_gcope.fec_pri_vencimiento  := nvl(i.fec_final, rg_gcope.fec_operacion + 1);
         rg_gcope.mto_ori_interes      := 0;
         rg_gcope.cta_con_int_original := NULL;
         rg_gcope.tas_nominal          := NULL;
         rg_gcope.cod_rub_primario     := fu_obt_rub_primario(v_cod_per_entidad);
         v_cod_rub_economico           := fu_obt_rub_primario(v_cod_per_entidad);
         rg_gcope.cod_rub_economico    := fu_obt_cod_bcp(v_cod_rub_economico);
         rg_gcope.cod_departamento     := fu_obt_ref_bco_central(v_cod_per_entidad);
         IF trim(rg_gcope.cod_departamento) IS NULL THEN
            rg_gcope.cod_departamento := 'B0';
         END IF;
         rg_gcope.dia_plazo            := nvl(i.plazo, 0);
         IF fu_pue_env_bcp(rg_gcope.tip_operacion) = 'S' THEN
            v_nro_registro        := v_nro_registro + 1;
            rg_gcope.nro_registro := v_nro_registro;
            --- Inserta Operaciones
            lp_ins_crc_operaciones(rg_gcope);
         ELSE
            rg_gcope.nro_registro := NULL;
            pr_ins_crc_ope_no_enviados(rg_gcope);
         END IF;
      END LOOP;
   END;
   PROCEDURE pr_crc_gen_movimientos IS
      rp_gcmov              sb_crc_movimientos_det%ROWTYPE;
      v_tot_lin_permanente  sb_crc_movimientos_det.mto_capital%TYPE;
      v_tot_lin_transitoria sb_crc_movimientos_det.mto_capital%TYPE;
      v_sal_sobregiro       sb_crc_movimientos_det.mto_capital%TYPE;
      v_rub_interes         sb_crc_movimientos_det.cta_con_interes%TYPE;
      v_rub_capital         sb_crc_movimientos_det.cta_con_capital%TYPE;
      v_mto_interes         sb_crc_movimientos_det.mto_interes%TYPE;
      v_cod_modalidad       ge_modalidades.cod_modalidad%TYPE;
      v_fecha               sb_crc_movimientos_det.fecha%TYPE;
      v_fec_apertura        date;
      v_dia_atraso          ta_cta_tarjetas.dia_mora%TYPE;
      v_cod_tip_cierre      ta_cta_tarjetas.cod_tip_cierre%TYPE;

      v_cod_moneda          ge_cuentas.cod_moneda%TYPE;
      v_cod_sec_contable    ge_clientes.cod_sec_contable%TYPE;
      v_cod_tip_deudor      ge_clientes.cod_tip_deudor%TYPE;
      v_residente           ge_clientes.residente%TYPE;
      v_estado              ge_cuentas.estado%TYPE;
      v_tip_cuenta          ge_tip_asientos.tip_cuenta%type;
      CURSOR c_operaciones IS
      -- sobregiro
      SELECT t.fecha,
             t.cod_modulo,
             t.cod_oficina,
             t.nro_operacion nro_cuenta,
             null nro_cta_vencida,
             to_char(t.tip_operacion) tip_operacion,
             t.cod_moneda,
             t.cta_con_cap_original,
             t.cta_con_int_original,
             t.tas_nominal,
             NULL estado,
             g.cod_modalidad,
             c.cod_sec_contable,
             c.cod_tip_deudor,
             c.residente,
             s.cod_sit_contable,
             s.cod_sub_modalidad,
             0 mto_capital
        FROM sb_crc_operaciones_det t, ge_cta_clientes g, ge_cuentas s, ge_clientes c,
        (SELECT ant.nro_cuenta, act.mto_linea
                    FROM ge_sal_diarios ant, ge_sal_diarios act
                   WHERE ant.fecha = v_fec_anterior
                     AND act.fecha = v_fec_actual
                     AND ant.nro_cuenta = act.nro_cuenta
                     AND nvl(ant.mto_linea, 0) <> nvl(act.mto_linea, 0)
                     AND nvl(ant.mto_linea, 0) <> 0) a
       WHERE g.nro_cuenta = t.nro_operacion
         AND c.cod_persona = g.cod_persona
         AND s.nro_cuenta = g.nro_cuenta
         and g.nro_cuenta = a.nro_cuenta
         AND g.relacion = 'P'
         and (t.cod_modulo = 4 AND t.mto_lin_credito > 0 AND mto_ori_capital = 0)
         union all
         --novedades de lineas de credito/ CRC informadas con nro_cuenta
      SELECT t.fecha,
             t.cod_modulo,
             t.cod_oficina,
             t.nro_operacion nro_cuenta,
             null nro_cta_vencida,
             to_char(t.tip_operacion) tip_operacion,
             t.cod_moneda,
             t.cta_con_cap_original,
             t.cta_con_int_original,
             t.tas_nominal,
             NULL estado,
             g.cod_modalidad,
             c.cod_sec_contable,
             c.cod_tip_deudor,
             c.residente,
             s.cod_sit_contable,
             s.cod_sub_modalidad,
             0 mto_capital
        FROM sb_crc_operaciones_det t, ge_cta_clientes g, ge_cuentas s, ge_clientes c,
        (SELECT ant.nro_cuenta, act.mto_linea
                    FROM ge_sal_diarios ant, ge_sal_diarios act
                   WHERE ant.fecha = v_fec_anterior
                     AND act.fecha = v_fec_actual
                     AND ant.nro_cuenta = act.nro_cuenta
                     AND nvl(ant.mto_linea, 0) <> nvl(act.mto_linea, 0)
                     AND nvl(ant.mto_linea, 0) <> 0) a
       WHERE g.nro_cuenta = t.nro_operacion
         AND c.cod_persona = g.cod_persona
         AND s.nro_cuenta = g.nro_cuenta
         and g.nro_cuenta = a.nro_cuenta
         AND g.relacion = 'P'
         AND t.cod_modulo = 5

      union all
         --novedades de lineas de credito/ CRC informadas con nro_plastico
          SELECT t.fecha,
             t.cod_modulo,
             t.cod_oficina,
             t.nro_operacion nro_cuenta,
             null nro_cta_vencida,
             to_char(t.tip_operacion) tip_operacion,
             t.cod_moneda,
             t.cta_con_cap_original,
             t.cta_con_int_original,
             t.tas_nominal,
             NULL estado,
             g.cod_modalidad,
             c.cod_sec_contable,
             c.cod_tip_deudor,
             c.residente,
             s.cod_sit_contable,
             s.cod_sub_modalidad,
             0 mto_capital
        FROM sb_crc_operaciones_det t, ge_cta_clientes g, ge_cuentas s, ge_clientes c, ta_tarjetas ta,
        (SELECT ant.nro_cuenta, act.mto_linea
                    FROM ge_sal_diarios ant, ge_sal_diarios act
                   WHERE ant.fecha = v_fec_anterior
                     AND act.fecha = v_fec_actual
                     AND ant.nro_cuenta = act.nro_cuenta
                     AND nvl(ant.mto_linea, 0) <> nvl(act.mto_linea, 0)
                     AND nvl(ant.mto_linea, 0) <> 0) a
       WHERE g.nro_cuenta = ta.nro_cuenta
         and ta.nro_tarjeta = t.nro_operacion
         AND c.cod_persona = g.cod_persona
         AND s.nro_cuenta = g.nro_cuenta
         and g.nro_cuenta = a.nro_cuenta
         AND g.relacion = 'P'
         AND t.cod_modulo = 5
      UNION ALL
      -- pasivas canceladas en la fecha
      SELECT i.fec_cam_estado,
             t.cod_modulo,
             t.cod_oficina,
             i.nro_cuenta,
             null nro_cta_vencida,
             to_char(t.tip_operacion) tip_operacion,
             t.cod_moneda,
             t.cta_con_cap_original,
             t.cta_con_int_original,
             0 tas_nominal,
             i.estado,
             i.cod_modalidad,
             c.cod_sec_contable,
             c.cod_tip_deudor,
             c.residente,
             i.cod_sit_contable,
             i.cod_sub_modalidad,
             0
        FROM ge_cuentas i , sb_crc_operaciones_det t, ge_clientes c, ge_cta_clientes g, ah_cta_certificados hc
       WHERE ((instr(v_tip_mod_cav_cancela,i.cod_modalidad||',')>0 and i.estado = 'C')--((i.cod_modalidad IN(31, 41, 37, 38, 39, 334) and estado = ('C'))
         or (i.cod_modalidad IN (33, 34) and (instr(v_tip_ope_cda_cancela,t.tip_operacion||',') = 0 AND i.estado IN ('C', 'T'))))  --or (i.cod_modalidad = 33 and t.tip_operacion not in (156,138) AND estado IN ('C', 'T'))) --CDA no se reporta.
         -- 'C' = Cancelado para ahorro vista /  'C' y 'T' = Totalmente Pagado para 33
         AND t.cod_modulo = i.cod_modulo
         AND hc.nro_cuenta(+) = i.nro_cuenta
         AND hc.cod_modalidad(+) = 34
         AND t.nro_operacion = NVL(hc.cod_isin, i.nro_cuenta)
         AND c.cod_persona = g.cod_persona
         AND g.nro_cuenta = i.nro_cuenta
         AND g.relacion = 'P'
         AND i.fec_cam_estado BETWEEN v_fec_inicio AND v_fec_fin
       -- CREDITOS POR CUENTA BASICA
       UNION ALL
       SELECT fecha,
             t.cod_modulo,
             t.cod_oficina,
             i.nro_cuenta,
             null nro_cta_vencida,
             to_char(t.tip_operacion) tip_operacion,
             t.cod_moneda,
             t.cta_con_cap_original,
             t.cta_con_int_original,
             0 tas_nominal,
             null estado,
             i.cod_modalidad,
             c.cod_sec_contable,
             c.cod_tip_deudor,
             c.residente,
             i.cod_sit_contable,
             i.cod_sub_modalidad,
             t.mto_ori_capital
        FROM ge_cuentas i , SB_CRC_MOV_CTA_BASICA t, ge_clientes c, ge_cta_clientes g
       WHERE i.cod_modalidad = 31
         AND i.cod_sub_modalidad = 26
         AND t.cod_modulo = i.cod_modulo
         AND t.nro_operacion = i.nro_cuenta
         AND c.cod_persona = g.cod_persona
         AND i.estado = 'C'
         AND g.nro_cuenta = i.nro_cuenta
         AND g.relacion = 'P'
         AND t.fecha BETWEEN v_fec_inicio AND v_fec_fin
       UNION ALL
      SELECT i.fec_cam_estado,
             t.cod_modulo,
             t.cod_oficina,
             i.nro_cuenta,
             o.nro_cuenta nro_cta_vencida,
             to_char(t.tip_operacion) tip_operacion,
             t.cod_moneda,
             t.cta_con_cap_original,
             t.cta_con_int_original,
             0 tas_nominal,
             i.estado,
             i.cod_modalidad,
             c.cod_sec_contable,
             c.cod_tip_deudor,
             c.residente,
             i.cod_sit_contable,
             i.cod_sub_modalidad,
             0
        FROM ge_cuentas i, sb_crc_operaciones_det t, ge_clientes c, ge_cta_clientes g,
             (SELECT nro_cta_origen, nro_cuenta
                FROM ov_cta_vencidas
               WHERE estado = 'C') o
       WHERE i.cod_modalidad = 41
         AND i.estado = 'C'
         AND t.cod_modulo = i.cod_modulo
         AND t.nro_operacion = i.nro_cuenta
         AND o.nro_cta_origen(+) = i.nro_cuenta
         AND c.cod_persona = g.cod_persona
         AND g.nro_cuenta = i.nro_cuenta
         AND g.relacion = 'P'
         AND i.fec_cam_estado BETWEEN v_fec_inicio AND v_fec_fin;

   PROCEDURE lp_crc_gen_dat_movimientos IS
   BEGIN
      pag_cal.pr_obt_dat_calendar(1);
      v_fec_actual   := pag_cal.fu_obt_fec_actual(1);
      v_fec_inicio   := pag_cal.fu_obt_fec_actual(1);
      v_fec_fin      := pag_cal.fu_obt_fec_actual(1);
      v_fec_anterior := pag_cal.g_fec_anterior;

      DELETE sb_crc_movimientos_det WHERE fecha = v_fec_fin;

      DELETE sb_crc_movimientos WHERE fec_periodo = v_fec_fin;
      COMMIT;
      v_nro_registro := 0;
   END;
   FUNCTION lf_obt_nov_linea(p_nro_cuenta ge_cuentas.nro_cuenta%TYPE) RETURN NUMBER IS
      v_mto_linea ge_sal_diarios.mto_linea%TYPE;
   BEGIN
      SELECT act.mto_linea
        INTO v_mto_linea
        FROM ge_sal_diarios ant, ge_sal_diarios act
       WHERE ant.fecha = v_fec_anterior
         AND act.fecha = v_fec_actual
         AND ant.nro_cuenta = act.nro_cuenta
         AND ant.nro_cuenta = p_nro_cuenta
         AND nvl(ant.mto_linea, 0) <> nvl(act.mto_linea, 0)
         AND nvl(ant.mto_linea, 0) <> 0;
      RETURN v_mto_linea;
   EXCEPTION
      WHEN OTHERS THEN
         RETURN 0;
   END;
   FUNCTION lf_obt_dia_plazo(p_nro_cuenta ge_cuentas.nro_cuenta%TYPE) RETURN NUMBER IS
      v_plazo sb_crc_movimientos_det.dia_plazo%TYPE;
   BEGIN
      SELECT s.fec_vencimiento - s.fec_inicio
        INTO v_plazo
        FROM cc_lin_sobregiros s
       WHERE s.nro_cuenta = p_nro_cuenta;
      RETURN v_plazo;
   EXCEPTION
      WHEN NO_DATA_FOUND THEN
         RETURN 0;
      WHEN OTHERS THEN
         RETURN 0;
   END;
   FUNCTION lf_obt_int_cancelacion(p_nro_cuenta ge_cuentas.nro_cuenta%TYPE,
                                   p_cod_modalidad ge_modalidades.cod_modalidad%TYPE) RETURN NUMBER IS
      v_mto_interes ge_movimientos.monto%TYPE;
   BEGIN
      IF p_cod_modalidad IN (33, 34) THEN
         SELECT SUM(nvl(monto,0))
           INTO v_mto_interes
           FROM ah_movimientos_his v
          WHERE v.nro_cuenta = p_nro_cuenta
            AND fecha BETWEEN v_fec_inicio and v_fec_fin
            AND cod_transaccion IN (658, 611);
      ELSIF p_cod_modalidad = 37 THEN
         SELECT SUM(nvl(monto,0))
           INTO v_mto_interes
           FROM ah_movimientos_his v
          WHERE v.nro_cuenta = p_nro_cuenta
            AND fecha BETWEEN v_fec_inicio and v_fec_fin
            AND cod_transaccion IN (658, 609); -- SE DEBEN CREAR LAS TRANSACCIONES
      ELSIF p_cod_modalidad = 31 THEN
         SELECT sum(nvl(monto,0))
           INTO v_mto_interes
           FROM ah_movimientos_his
          WHERE nro_cuenta = p_nro_cuenta
            AND fecha BETWEEN v_fec_inicio and v_fec_fin
            AND cod_transaccion = 609;
      ELSIF p_cod_modalidad = 41 THEN
          SELECT sum(nvl(monto,0))
           INTO v_mto_interes
           FROM cc_movimientos_his
          WHERE nro_cuenta = p_nro_cuenta
            AND fecha BETWEEN v_fec_inicio and v_fec_fin
            AND cod_transaccion = 550;
      END IF;
      RETURN v_mto_interes;
   EXCEPTION
      WHEN OTHERS THEN
         RETURN 0;
   END;
    --Procedimiento de inserci?n de Archivo de Movimientos
   PROCEDURE lp_ins_crc_movimientos(rp_gcmov sb_crc_movimientos_det%ROWTYPE) IS
   BEGIN
      INSERT INTO sb_crc_movimientos_det
         (fecha, nom_referencia, nro_formulario, cod_oficina, tip_operacion, nro_operacion,
          cod_mon_iso, fec_operacion, cta_con_capital, mto_capital, mto_lin_credito, cta_con_interes,
          mto_interes, tas_nominal, dia_plazo, tip_movimiento, nro_registro)
      VALUES
         (rp_gcmov.fecha, rp_gcmov.nom_referencia, rp_gcmov.nro_formulario,
          nvl(fug_obt_pardinamico('COD_OFI_NO_HAB_BCP', NULL, NULL, NULL, rp_gcmov.cod_oficina),
               rp_gcmov.cod_oficina), rp_gcmov.tip_operacion, rp_gcmov.nro_operacion,
          rp_gcmov.cod_mon_iso, rp_gcmov.fec_operacion, rp_gcmov.cta_con_capital,
          nvl(pag_gen.fu_con_mon_a_moneda(decode(rp_gcmov.cod_mon_iso, 'PYG',
                                                  v_cod_mon_local, rp_gcmov.cod_mon_iso),
                                           v_cod_mon_local, rp_gcmov.mto_capital, NULL,
                                           rp_gcmov.fec_operacion, NULL), 0),
          nvl(pag_gen.fu_con_mon_a_moneda(decode(rp_gcmov.cod_mon_iso, 'PYG',
                                                  v_cod_mon_local, rp_gcmov.cod_mon_iso),
                                           v_cod_mon_local, rp_gcmov.mto_lin_credito, NULL,
                                           rp_gcmov.fec_operacion, NULL), 0),
          rp_gcmov.cta_con_interes,
          nvl(pag_gen.fu_con_mon_a_moneda(decode(rp_gcmov.cod_mon_iso, 'PYG',
                                                  v_cod_mon_local, rp_gcmov.cod_mon_iso),
                                           v_cod_mon_local, rp_gcmov.mto_interes, NULL,
                                           rp_gcmov.fec_operacion, NULL), 0), rp_gcmov.tas_nominal,
          rp_gcmov.dia_plazo, rp_gcmov.tip_movimiento, rp_gcmov.nro_registro);
   END;
   PROCEDURE lp_obt_dat_cta_pasivas
     (
        p_nro_cuenta       IN  ge_cta_clientes.nro_cuenta%TYPE,
        p_sal_capital      OUT sb_crc_movimientos_det.mto_capital%TYPE,
        p_sal_interes      OUT sb_crc_movimientos_det.mto_interes%TYPE
     ) IS
   BEGIN
      SELECT h.sal_total,
             0 sal_interes -- se calcula con otra funcion.
        INTO p_sal_capital,
             p_sal_interes
        FROM ge_cuentas p, ge_cta_clientes b, ge_est_cuentas g ,ah_cta_certificados h
       WHERE p.nro_cuenta = b.nro_cuenta
         AND b.relacion = 'P'
         AND p.estado = g.estado
         AND h.nro_cuenta = b.nro_cuenta
         AND p.cod_modulo = g.cod_modulo
         AND p.cod_modalidad = g.cod_modalidad
         AND g.estado IN ('C','T')
         AND h.nro_cuenta = p_nro_cuenta
       UNION
      SELECT nvl(h.sal_tot_batch, 0) - nvl(h.sal_ret_batch, 0) sal_capital,
             0 sal_interes
        FROM ge_cuentas p, ge_cta_clientes b, ge_est_cuentas g ,ah_cta_vistas h
       WHERE p.nro_cuenta = b.nro_cuenta
         AND h.nro_cuenta = b.nro_cuenta
         AND b.relacion = 'P'
         AND p.estado = g.estado
         AND p.cod_modulo = g.cod_modulo
         AND p.cod_modalidad = g.cod_modalidad
         AND g.estado = 'C'
         AND h.nro_cuenta = p_nro_cuenta
        UNION
      SELECT nvl((nvl(sal_tot_batch, 0) - nvl(sal_blo_batch, 0) - nvl(sal_ret_batch, 0)),
                0) sal_capital,
             0 sal_interes
        FROM ge_cuentas p, ge_cta_clientes b, ge_est_cuentas g ,cc_cta_corrientes h
       WHERE p.nro_cuenta = b.nro_cuenta
         AND h.nro_cuenta = b.nro_cuenta
         AND b.relacion = 'P'
         AND p.estado = g.estado
         AND p.cod_modulo = g.cod_modulo
         AND p.cod_modalidad = g.cod_modalidad
         AND g.estado = 'C'
         AND h.nro_cuenta = p_nro_cuenta;
   EXCEPTION
      WHEN NO_DATA_FOUND THEN
         NULL;
      WHEN OTHERS THEN
         p_sal_capital    := 0;
         p_sal_interes    := 0;
   END;
   BEGIN
      -- inicializar registros
      lp_crc_gen_dat_movimientos;
      rp_gcmov.nom_referencia := 'MOVIMIENTO';
      rp_gcmov.nro_formulario := '012';
      --Recorrer cursor c_operaciones
      FOR i IN c_operaciones LOOP
          rp_gcmov.fecha         := v_fec_fin;
          rp_gcmov.cod_oficina   := i.cod_oficina;
          rp_gcmov.nro_operacion := i.nro_cuenta;
          IF i.cod_modalidad = 34 THEN
             SELECT NVL(h.cod_isin, i.nro_cuenta)
               INTO rp_gcmov.nro_operacion
               FROM ah_cta_certificados h
              WHERE h.nro_cuenta = i.nro_cuenta;
          END IF;
          rp_gcmov.cod_mon_iso   := i.cod_moneda;
          rp_gcmov.fec_operacion := v_fec_actual;
          IF i.estado IN ('C', 'T') THEN
             -- Cancelaci?n de ctas. pasivas
             v_rub_capital            := pab_asi.fu_obt_rub_contable(nvl(i.nro_cta_vencida,i.nro_cuenta), 'C');
             v_rub_interes            := pab_asi.fu_obt_rub_contable(nvl(i.nro_cta_vencida,i.nro_cuenta), 'I');
             v_tip_cuenta := null;
             IF v_rub_capital IS NULL THEN
                v_rub_capital  := pab_asi.fu_obt_rub_con_his(nvl(i.nro_cta_vencida,i.nro_cuenta),'C',pag_cal.fu_obt_fec_ant_hab(i.fecha, NULL, 1),'N');
                IF v_rub_capital IS NULL THEN
                   if i.cod_modulo = 3 and i.cod_modalidad = 31 then
                      begin
                        v_tip_cuenta := fue_obt_val_max_refcodes('TIP_CTA_SUB_MOD_CONTABLE',trim(i.cod_modulo)||i.cod_modalidad||i.cod_sub_modalidad);
                      exception
                        when others then
                           v_tip_cuenta := null;
                      end;
                   end if;
                   v_rub_capital := IT.pas_cri.fu_obt_cod_rubro(i.nro_cuenta, i.cod_modulo, i.cod_modalidad, 602, i.cod_moneda,
                                                 i.cod_sec_contable, i.cod_tip_deudor, i.residente, NULL,
                                                 'C', i.cod_sit_contable, i.estado, NULL, NULL, NULL,v_tip_cuenta);
                   IF v_rub_capital IS NULL THEN
                      BEGIN
                      SELECT MAX(h.fecha)
                        INTO v_fecha
                        FROM cb_sal_inventarios_his  h, cb_sal_inventarios_det_his c
                       WHERE c.nro_referencia = h.nro_referencia
                         AND c.nro_cuenta = nvl(i.nro_cta_vencida,i.nro_cuenta)
                         AND h.tip_saldo = 'C';
                      EXCEPTION
                         WHEN NO_DATA_FOUND THEN
                            v_rub_capital := NULL;
                         WHEN OTHERS THEN
                            NULL;
                      END;
                      IF v_fecha IS NOT NULL THEN
                         v_rub_capital  := pab_asi.fu_obt_rub_con_his(nvl(i.nro_cta_vencida,i.nro_cuenta),'C',v_fecha,'N');
                      END IF;
                   END IF;
                END IF;
             END IF;
             IF v_rub_interes IS NULL THEN
                v_rub_interes := pab_asi.fu_obt_rub_contable(i.nro_cuenta, 'D');
             END IF;
             rp_gcmov.cta_con_capital := v_rub_capital;
             rp_gcmov.cta_con_interes := v_rub_interes;
             rp_gcmov.tip_operacion   := i.tip_operacion;
             rp_gcmov.tip_movimiento  := 'CC';
             lp_obt_dat_cta_pasivas (i.nro_cuenta,rp_gcmov.mto_capital,v_mto_interes);
             rp_gcmov.mto_interes     := lf_obt_int_cancelacion(i.nro_cuenta, i.cod_modalidad);
             rp_gcmov.mto_lin_credito := 0;
             rp_gcmov.dia_plazo       := 0;
             rp_gcmov.tas_nominal     := 0;
          --cuenta basica
          ELSIF i.cod_modulo = 3 and i.cod_sub_modalidad = 26 AND i.estado is null THEn
                rp_gcmov.mto_lin_credito := lf_obt_nov_linea(i.nro_cuenta);
                rp_gcmov.tip_operacion   := i.tip_operacion;
                rp_gcmov.cta_con_capital := i.cta_con_cap_original;
                rp_gcmov.cta_con_interes := i.cta_con_int_original;
                rp_gcmov.tip_movimiento  := 'CR';
                rp_gcmov.mto_capital     := i.mto_capital;
                rp_gcmov.cta_con_interes := i.cta_con_int_original;
                rp_gcmov.mto_interes     := 0;
                rp_gcmov.dia_plazo       := lf_obt_dia_plazo(i.nro_cuenta);
                rp_gcmov.tas_nominal     := i.tas_nominal;
          ELSIF i.cod_modulo = 5 THEN
             -- Renovaci?n y/o aumento de l?nea de cr?dito
             IF lf_obt_nov_linea(i.nro_cuenta) = 0 THEN
                GOTO siguiente;
             END IF;
             rp_gcmov.mto_lin_credito := lf_obt_nov_linea(i.nro_cuenta);
             rp_gcmov.tip_operacion   := i.tip_operacion;
             rp_gcmov.cta_con_capital := i.cta_con_cap_original;
             rp_gcmov.cta_con_interes := i.cta_con_int_original;
             rp_gcmov.tip_movimiento  := 'RN';
             lp_obt_dat_tarjeta (i.nro_cuenta, v_cod_modalidad, v_fec_apertura,
                                  rp_gcmov.mto_capital, v_dia_atraso, v_cod_tip_cierre, rp_gcmov.tas_nominal,
                                  v_cod_moneda, v_cod_sec_contable, v_cod_tip_deudor, v_residente, v_estado);
             rp_gcmov.mto_interes := 0;
             rp_gcmov.dia_plazo   := 0;
          ELSIF i.cod_modulo = 4 AND i.estado IS NULL THEN
           -- Renovaci?n y/o aumento de l?nea de sobregiro
             IF lf_obt_nov_linea(i.nro_cuenta) != 0 THEN
                rp_gcmov.mto_lin_credito := lf_obt_nov_linea(i.nro_cuenta);
                rp_gcmov.tip_operacion   := i.tip_operacion;
                rp_gcmov.cta_con_capital := i.cta_con_cap_original;
                rp_gcmov.tip_movimiento  := 'RN';
                rp_gcmov.mto_capital     := 0;
                rp_gcmov.cta_con_interes := i.cta_con_int_original;
                rp_gcmov.mto_interes     := 0;
                rp_gcmov.dia_plazo       := lf_obt_dia_plazo(i.nro_cuenta);
                rp_gcmov.tas_nominal     := i.tas_nominal;
                v_nro_registro        := v_nro_registro + 1;
                rp_gcmov.nro_registro := v_nro_registro;
                -- Inserta la renovaci?n
                lp_ins_crc_movimientos(rp_gcmov);
                lp_act_tot_registro(v_fec_fin, 'SB_CRC_MOVIMIENTOS');
             END IF;
             -- Entradas en sobregiro
             pac_sob.pr_obt_mto_uti_lineas(i.nro_cuenta, v_tot_lin_permanente, v_tot_lin_transitoria,
                                           v_sal_sobregiro);
             IF nvl(v_sal_sobregiro, 0) + nvl(v_tot_lin_permanente, 0) + nvl(v_tot_lin_transitoria, 0) <> 0 THEN
                rp_gcmov.mto_capital     := nvl(v_sal_sobregiro, 0) + nvl(v_tot_lin_permanente, 0) + nvl(v_tot_lin_transitoria, 0);
                rp_gcmov.mto_capital     := v_sal_sobregiro;
                rp_gcmov.tip_operacion   := i.tip_operacion;
                rp_gcmov.cta_con_capital := i.cta_con_cap_original;
                rp_gcmov.cta_con_interes := i.cta_con_int_original;
                rp_gcmov.tip_movimiento  := 'SG';
                rp_gcmov.mto_interes     := lf_obt_int_cancelacion(i.nro_cuenta, i.cod_modalidad);
                rp_gcmov.mto_lin_credito := 0;
                rp_gcmov.dia_plazo       := 0;
                rp_gcmov.tas_nominal     := i.tas_nominal;
             ELSE
                GOTO siguiente;
             END IF;
          END IF;
           v_nro_registro        := v_nro_registro + 1;
          rp_gcmov.nro_registro := v_nro_registro;
          -- Inserta los movimientos
          lp_ins_crc_movimientos(rp_gcmov);
          lp_act_tot_registro(v_fec_fin, 'SB_CRC_MOVIMIENTOS');
          -- Siguiente registro
          <<siguiente>>
          NULL;
      END LOOP;
   END;
   -- Funcion para obtener el codigo primario de la actividad
   FUNCTION fu_obt_rub_primario(p_cod_persona VARCHAR2) RETURN VARCHAR2 IS
      v_cod_rub_primario ba_personas.cod_rub_primario%TYPE;
   BEGIN
      SELECT a.cod_rub_primario
        INTO v_cod_rub_primario
        FROM ba_personas a
       WHERE cod_persona = p_cod_persona;
      RETURN v_cod_rub_primario;
   EXCEPTION
      WHEN OTHERS THEN
         RETURN NULL;
   END;
   -- Funcion para obtener el rubro de la actividad
   FUNCTION fu_obt_rub_economico(p_nro_cuenta ge_cuentas.nro_cuenta%TYPE, p_nom_tabla VARCHAR2) RETURN VARCHAR2 IS
      TYPE t_tipo_cursor IS REF CURSOR;
      c_cursor            t_tipo_cursor;
      v_cod_rub_economico pr_cta_prestamos.cod_rub_economico%TYPE;
      v_sql               VARCHAR2(2000);
   BEGIN
      /**
      || El Destino se obtendra de los maestros correspondientes la columna COD_RUB_ECONOMICO:
      || PR_CTA_PRESTAMOS
      || TA_CTA_TARJETAS
      || CC_LIN_SOBREGIROS
      || CX_FIANZAS
      || MD_CTA_DOCUMENTOS
      || OV_CTA_VENCIDAS
      **/
      v_sql := ' select cod_rub_economico from ' || p_nom_tabla || '  where nro_cuenta = ' || '''' || p_nro_cuenta || '''';
      OPEN c_cursor FOR v_sql;
      LOOP
         FETCH c_cursor
            INTO v_cod_rub_economico;
         EXIT WHEN c_cursor%NOTFOUND;
      END LOOP;
      RETURN v_cod_rub_economico;
   EXCEPTION
      WHEN OTHERS THEN
         RETURN NULL;
   END;

   -- Funcion para obtener el codigo de departamento del banco central a partir del codigo de persona
   FUNCTION fu_obt_ref_bco_central(p_cod_persona ba_personas.cod_persona%TYPE) RETURN VARCHAR2 IS
      v_ref_bco_central ba_departamentos.ref_bco_central%TYPE;
      v_cod_pais        ba_paises.cod_pais%TYPE;
   BEGIN

      SELECT nvl(d.ref_bco_central,'B0'), a.cod_pais --fieldesk-14837-ajuste para Dto. cheque/documento, departamento nulo
        INTO v_ref_bco_central, v_cod_pais
        FROM ba_direcciones a, ba_ciudades c, ba_departamentos d
       WHERE cod_persona = p_cod_persona
         AND principal = 'S'
         AND a.cod_ciudad = c.cod_ciudad
         AND c.cod_pais = a.cod_pais
         AND c.cod_departamento = d.cod_departamento;
      RETURN v_ref_bco_central;
   EXCEPTION
      WHEN no_data_found THEN
         v_ref_bco_central := 'B0';
         RETURN v_ref_bco_central;
      WHEN too_many_rows THEN
         IF v_cod_pais = 1 THEN
            v_ref_bco_central := 'B0';
         ELSE
            v_ref_bco_central := 'Z0';
         END IF;
         RETURN v_ref_bco_central;
      WHEN OTHERS THEN
         v_ref_bco_central := 'B0';
         RETURN v_ref_bco_central;
   END;
   -- obtiene el codigo de rubro que corresponde a una cuenta
   FUNCTION fu_obt_cod_rubro
   (
      p_nro_cuenta       IN VARCHAR2 DEFAULT NULL,
      p_cod_modulo       IN NUMBER DEFAULT NULL,
      p_cod_modalidad    IN NUMBER DEFAULT NULL,
      p_cod_transaccion  IN NUMBER,
      p_cod_moneda       IN VARCHAR2 DEFAULT NULL,
      p_cod_sec_contable IN VARCHAR2 DEFAULT NULL,
      p_cod_tip_deudor   IN NUMBER DEFAULT NULL,
      p_residente        IN VARCHAR2 DEFAULT NULL,
      p_cod_plazo        IN VARCHAR2,
      p_tip_movimiento   IN VARCHAR2,
      p_cod_sit_contable IN NUMBER DEFAULT NULL,
      p_est_cuenta       IN VARCHAR2 DEFAULT NULL,
      p_tip_renovacion   IN VARCHAR2 DEFAULT NULL,
      p_cat_automatica   IN NUMBER DEFAULT NULL,
      p_tip_interes      IN VARCHAR2 DEFAULT NULL,
      p_tip_cuenta       IN VARCHAR2 DEFAULT NULL,
      p_cod_sec_credito  IN NUMBER DEFAULT NULL
   ) RETURN VARCHAR2 IS
      v_cod_tip_asiento  ge_tip_asientos.cod_tip_asiento%TYPE;
      v_cod_tip_asiento2 ge_tip_asientos.cod_tip_asiento%TYPE;
      v_ind_deudor       ge_tip_asientos.ind_deudor%TYPE;
      v_ind_plazo        ge_tip_asientos.ind_plazo%TYPE;
      v_ind_producto     ge_tip_asientos.ind_producto%TYPE;
      p_cod_rubro        ge_tip_asientos.cod_rubro%TYPE;
      v_cod_pro_contable ge_modalidades.cod_pro_contable%TYPE;
      v_cod_plazo        ge_plz_contables.cod_plazo%TYPE;
      v_fec_vencimiento  ge_cuentas.fec_vencimiento%TYPE;
      v_fec_apertura     ge_cuentas.fec_apertura%TYPE;
      v_cod_sec_contable ge_clientes.cod_sec_contable%TYPE;
      v_cod_tip_deudor   ge_clientes.cod_tip_deudor%TYPE;
      v_residente        ge_clientes.residente%TYPE;
      v_cod_sit_contable ge_cuentas.cod_sit_contable%TYPE;
      v_cod_modulo       ge_cuentas.cod_modulo%TYPE;
      v_cod_modalidad    ge_cuentas.cod_modalidad%TYPE;
      v_cod_moneda       ge_cuentas.cod_moneda%TYPE;

   BEGIN

     IF p_cod_modulo IS NOT NULL AND p_cod_modalidad IS NOT NULL THEN
         v_cod_modulo       := p_cod_modulo;
         v_cod_modalidad    := p_cod_modalidad;
         v_cod_moneda       := p_cod_moneda;
         v_cod_sec_contable := 'N';
         v_residente        := 'S';
      END IF;

      /*Busco datos del Cliente*/
      IF p_nro_cuenta IS NOT NULL THEN
         SELECT d.cod_modulo, d.cod_modalidad, d.cod_moneda, b.cod_sec_contable, nvl(b.cod_tip_deudor,0), b.residente,
                d.cod_sit_contable, d.fec_vencimiento, d.fec_apertura
           INTO v_cod_modulo, v_cod_modalidad, v_cod_moneda, v_cod_sec_contable, v_cod_tip_deudor, v_residente,
                v_cod_sit_contable, v_fec_vencimiento, v_fec_apertura
           FROM ge_cta_clientes g, ge_clientes b, ge_cuentas d
          WHERE g.cod_persona = b.cod_persona
            AND g.nro_cuenta = d.nro_cuenta
            AND g.nro_cuenta = p_nro_cuenta
            AND g.relacion = 'P';
      END IF;

      IF p_cod_plazo IS NULL THEN
         v_cod_plazo := fug_obt_plz_contable(nvl(v_fec_vencimiento - v_fec_apertura, 0));
      ELSE
         v_cod_plazo := p_cod_plazo;
      END IF;

      /* busco la transaccion que le corresponde */
      SELECT tr.cod_tip_asiento, cod_tip_asiento2, cod_pro_contable
        INTO v_cod_tip_asiento, v_cod_tip_asiento2, v_cod_pro_contable
        FROM ge_modalidades mo, ge_transacciones tr
       WHERE tr.cod_transaccion = p_cod_transaccion
         AND tr.cod_modulo = v_cod_modulo
         AND tr.cod_modalidad = v_cod_modalidad
         AND mo.cod_modulo = tr.cod_modulo
         AND mo.cod_modalidad = tr.cod_modalidad;

      /* busco la cuenta contable que le corresponde */
      SELECT ind_plazo, ind_deudor, cod_rubro, ind_producto
        INTO v_ind_plazo, v_ind_deudor, p_cod_rubro, v_ind_producto
        FROM ge_tip_asientos
       WHERE cod_tip_asiento IN (v_cod_tip_asiento, v_cod_tip_asiento2)
         AND cod_moneda = v_cod_moneda
         AND (cod_sec_contable IS NULL OR cod_sec_contable = v_cod_sec_contable)
         AND (tip_renovacion IS NULL OR tip_renovacion = nvl(p_tip_renovacion, 'A'))
         AND (tip_interes IS NULL OR tip_interes = p_tip_interes)
         AND ((nvl(p_tip_cuenta, 'x') = 'B' and tip_cuenta = p_tip_cuenta) or
             (nvl(p_tip_cuenta, 'x') <> 'B' and (tip_cuenta IS NULL OR tip_cuenta = p_tip_cuenta)))
         AND (cat_automatica IS NULL OR cat_automatica = p_cat_automatica)
         AND (est_cuenta IS NULL OR est_cuenta = p_est_cuenta)
         AND (ind_residente = 'X' OR ind_residente = v_residente)
         AND (cod_sit_contable IS NULL OR cod_sit_contable = p_cod_sit_contable)
         AND tip_movimiento = p_tip_movimiento
         AND nro_linea =
             (SELECT MIN(nro_linea)
                FROM ge_tip_asientos
               WHERE cod_tip_asiento IN (v_cod_tip_asiento, v_cod_tip_asiento2)
                 AND cod_moneda = v_cod_moneda
                 AND (cod_sec_contable IS NULL OR cod_sec_contable = v_cod_sec_contable)
                 AND (tip_renovacion IS NULL OR tip_renovacion = nvl(p_tip_renovacion, 'A'))
                 AND (tip_interes IS NULL OR tip_interes = p_tip_interes)
                 AND (tip_cuenta IS NULL OR tip_cuenta = p_tip_cuenta)
                 AND (cat_automatica IS NULL OR cat_automatica = p_cat_automatica)
                 AND (est_cuenta IS NULL OR est_cuenta = p_est_cuenta)
                 AND (ind_residente = 'X' OR ind_residente = v_residente)
                 AND (cod_sit_contable IS NULL OR cod_sit_contable = v_cod_sit_contable)
                 AND tip_movimiento = p_tip_movimiento)
         AND rownum = 1;

      IF v_ind_plazo = 'S' THEN
         p_cod_rubro := substr(p_cod_rubro, 1, 2) || v_cod_plazo || substr(p_cod_rubro, 4, 12);
      END IF;
      IF v_ind_deudor = 'S' OR substr(p_cod_rubro, 9, 2) = 'TD' THEN
         p_cod_rubro := substr(p_cod_rubro, 1, 8) || ltrim(to_char(nvl(p_cod_tip_deudor,v_cod_tip_deudor), '00')) ||
                        substr(p_cod_rubro, 11, 5);
      END IF;
      ---Reemplaza el codigo del producto -----------------------
      IF v_ind_producto = 'S' THEN
         p_cod_rubro := substr(p_cod_rubro, 1, 10) || ltrim(to_char(v_cod_pro_contable, '000')) ||
                        substr(p_cod_rubro, 14, 2);
      END IF;
      IF substr(p_cod_rubro, 11, 3) = 'SEC' THEN
         -- es solo para prestamos, para contabilizar por sector
         p_cod_rubro := substr(p_cod_rubro, 1, 10) ||
                        ltrim(to_char(fup_obt_sec_rubro(p_cod_sec_credito), '000')) ||
                        substr(p_cod_rubro, 14, 2);
      END IF;
      RETURN p_cod_rubro;
   EXCEPTION
      WHEN OTHERS THEN
         p_cod_rubro := NULL;
         RETURN p_cod_rubro;
   END;
FUNCTION fu_obt_rub_contable
   (
      p_cod_modulo IN ba_modulos.cod_modulo%TYPE,
      p_nro_cuenta IN ge_cuentas.nro_cuenta%TYPE,
      p_tip_monto  IN VARCHAR2 DEFAULT NULL
   ) RETURN VARCHAR2 IS

      v_rubro ge_tip_asientos.cod_rubro%TYPE;
   BEGIN
      IF p_cod_modulo = 8 THEN
         DECLARE
            CURSOR datos IS
               SELECT a.cod_modulo,
                      a.cod_modalidad,
                      decode(p_tip_monto, 'U', 890, 874) cod_transaccion,
                      a.cod_moneda,
                      c.cod_sec_contable,
                      c.cod_tip_deudor,
                      c.residente,
                      1 cod_plazo,
                      'D' tip_movimiento,
                      a.cod_sit_contable
                 FROM ge_clientes c, ge_cta_clientes b, ge_cuentas a
                WHERE a.nro_cuenta = p_nro_cuenta
                  AND b.nro_cuenta = a.nro_cuenta
                  AND b.relacion = 'P'
                  AND c.cod_persona = b.cod_persona;
            reg datos%ROWTYPE;
         BEGIN
            OPEN datos;
            FETCH datos
             INTO reg;
            CLOSE datos;

            RETURN IT.pas_cri.fu_obt_cod_rubro(p_nro_cuenta, reg.cod_modulo, reg.cod_modalidad, reg.cod_transaccion,
                                            reg.cod_moneda, reg.cod_sec_contable, reg.cod_tip_deudor,
                                            reg.residente, reg.cod_plazo, reg.tip_movimiento,
                                            reg.cod_sit_contable);
         END;

      END IF;
      IF p_cod_modulo = 10 THEN
         DECLARE
            CURSOR datos IS
               SELECT a.cod_modulo,
                      a.cod_modalidad,
                      t.cod_transaccion,
                      a.cod_moneda,
                      c.cod_sec_contable,
                      c.cod_tip_deudor,
                      c.residente,
                      fug_obt_plz_contable(nvl(a.fec_vencimiento - a.fec_apertura, 0)) cod_plazo,
                      s.tip_movimiento,
                      a.cod_sit_contable
                 FROM ge_clientes      c,
                      ge_cta_clientes  b,
                      ge_cuentas       a,
                      ge_transacciones t,
                      ge_tip_asientos  s
                WHERE a.nro_cuenta = p_nro_cuenta
                  AND b.nro_cuenta = a.nro_cuenta
                  AND t.cod_tip_asiento = s.cod_tip_asiento
                  AND t.cod_modulo = a.cod_modulo
                  AND t.cod_modalidad = a.cod_modalidad
                  AND s.cod_moneda = a.cod_moneda
                  AND b.relacion = 'P'
                  AND c.cod_persona = b.cod_persona
                  AND s.tip_movimiento = 'D'
                  AND t.cod_transaccion = 711
                  AND a.estado <> 'S';

            reg datos%ROWTYPE;
         BEGIN
            OPEN datos;
            FETCH datos
               INTO reg;
            CLOSE datos;

            RETURN IT.pas_cri.fu_obt_cod_rubro(p_nro_cuenta, reg.cod_modulo, reg.cod_modalidad, reg.cod_transaccion,
                                            reg.cod_moneda, reg.cod_sec_contable, reg.cod_tip_deudor,
                                            reg.residente, reg.cod_plazo, reg.tip_movimiento,
                                            reg.cod_sit_contable);

         END;
      END IF;
      RETURN v_rubro;
   EXCEPTION
      WHEN no_data_found THEN
         RETURN NULL;
      WHEN OTHERS THEN
         RETURN NULL;
   END;
   FUNCTION fu_obt_mon_iso(p_cod_moneda IN ba_monedas.cod_moneda%TYPE) RETURN VARCHAR2 IS

      v_cod_mon_iso ba_monedas.cod_mon_iso%TYPE;
   BEGIN
      --Obtiene el Codigo Iso de la moneda
      SELECT cod_mon_iso
        INTO v_cod_mon_iso
        FROM ba_monedas
       WHERE cod_moneda = p_cod_moneda;

      RETURN v_cod_mon_iso;

   EXCEPTION
      WHEN no_data_found THEN
         RETURN NULL;
   END;
  FUNCTION fu_obt_cod_moneda(p_cod_mon_iso IN ba_monedas.cod_mon_iso%TYPE) RETURN VARCHAR2 IS

      v_cod_moneda ba_monedas.cod_moneda%TYPE;
   BEGIN
      --Obtiene el C?digo de la moneda
      SELECT cod_moneda INTO v_cod_moneda FROM ba_monedas WHERE cod_mon_iso = p_cod_mon_iso;

      RETURN v_cod_moneda;

   EXCEPTION
      WHEN no_data_found THEN
         RETURN NULL;
   END;
   FUNCTION fu_obt_rub_resultado(p_nro_cuenta      IN VARCHAR2,
                                 p_cod_transaccion IN NUMBER,
                                 p_cod_plazo       IN VARCHAR2,
                                 p_tip_movimiento  IN VARCHAR2,
                                 p_est_cuenta      IN VARCHAR2 DEFAULT NULL,
                                 p_tip_renovacion  IN VARCHAR2 DEFAULT NULL,
                                 p_tip_interes     IN VARCHAR2 DEFAULT NULL,
                                 p_tip_cuenta      IN VARCHAR2 DEFAULT NULL,
                                 p_cod_sec_credito IN NUMBER DEFAULT NULL,
                                 p_cod_moneda      IN VARCHAR2 DEFAULT NULL) RETURN VARCHAR2 IS
      v_cod_tip_asiento  ge_tip_asientos.cod_tip_asiento%TYPE;
      v_cod_tip_asiento2 ge_tip_asientos.cod_tip_asiento%TYPE;
      v_ind_deudor       ge_tip_asientos.ind_deudor%TYPE;
      v_ind_plazo        ge_tip_asientos.ind_plazo%TYPE;
      v_ind_producto     ge_tip_asientos.ind_producto%TYPE;
      p_cod_rubro        ge_tip_asientos.cod_rubro%TYPE;
      v_cod_pro_contable ge_modalidades.cod_pro_contable%TYPE;
      v_cod_sec_contable ge_clientes.cod_sec_contable%TYPE;
      v_cod_tip_deudor   ge_clientes.cod_tip_deudor%TYPE;
      v_residente        ge_clientes.residente%TYPE;
      v_cod_sit_contable ge_cuentas.cod_sit_contable%TYPE;
      v_cod_modulo       ge_cuentas.cod_modulo%TYPE;
      v_cod_modalidad    ge_cuentas.cod_modalidad%TYPE;
      v_cod_moneda       ge_cuentas.cod_moneda%TYPE;
      v_fec_vencimiento  ge_cuentas.fec_vencimiento%TYPE;
      v_fec_apertura     ge_cuentas.fec_apertura%TYPE;
      v_cod_plazo        ge_plz_contables.cod_plazo%TYPE;
      v_cat_automatica   ge_clientes.cat_automatica%TYPE;
   BEGIN
      /*Busco datos del Cliente*/
      SELECT d.cod_modulo, d.cod_modalidad, d.cod_moneda, b.cod_sec_contable, b.cod_tip_deudor, b.residente,
             d.cod_sit_contable, d.fec_vencimiento, d.fec_apertura, b.cat_riesgo
        INTO v_cod_modulo, v_cod_modalidad, v_cod_moneda, v_cod_sec_contable, v_cod_tip_deudor, v_residente,
             v_cod_sit_contable, v_fec_vencimiento, v_fec_apertura, v_cat_automatica
        FROM ge_cta_clientes g, ge_clientes b, ge_cuentas d
       WHERE g.cod_persona = b.cod_persona
         AND g.nro_cuenta = d.nro_cuenta
         AND g.nro_cuenta = p_nro_cuenta
         AND g.relacion = 'P';

      IF p_cod_plazo IS NULL THEN
         v_cod_plazo := fug_obt_plz_contable(nvl(v_fec_vencimiento - v_fec_apertura, 0));
      ELSE
         v_cod_plazo := p_cod_plazo;
      END IF;
      /* busco la transaccion que le corresponde */
      SELECT tr.cod_tip_asiento, cod_tip_asiento2, cod_pro_contable
        INTO v_cod_tip_asiento, v_cod_tip_asiento2, v_cod_pro_contable
        FROM ge_modalidades mo, ge_transacciones tr
       WHERE tr.cod_modulo = v_cod_modulo
         AND tr.cod_modalidad = v_cod_modalidad
         AND tr.cod_transaccion = p_cod_transaccion
         AND mo.cod_modulo = v_cod_modulo
         AND mo.cod_modalidad = v_cod_modalidad;
      /* busco la cuenta contable que le corresponde */
      IF v_cod_modulo = 5 THEN
         SELECT cod_rubro, ind_plazo, ind_deudor, ind_producto
           INTO p_cod_rubro, v_ind_plazo, v_ind_deudor, v_ind_producto
           FROM ge_tip_asientos a
          WHERE cod_tip_asiento IN (v_cod_tip_asiento2)
            AND cod_moneda = nvl(p_cod_moneda, v_cod_moneda)
            AND tip_movimiento = p_tip_movimiento;
      ELSE
         SELECT cod_rubro, ind_plazo, ind_deudor, ind_producto
           INTO p_cod_rubro, v_ind_plazo, v_ind_deudor, v_ind_producto
           FROM ge_tip_asientos a
          WHERE cod_tip_asiento IN (v_cod_tip_asiento, v_cod_tip_asiento2)
            AND cod_moneda = nvl(p_cod_moneda, v_cod_moneda)
            AND (cod_sec_contable = v_cod_sec_contable OR cod_sec_contable IS NULL)
            AND (ind_residente = v_residente OR ind_residente = 'X')
            AND (est_cuenta = p_est_cuenta OR nvl(est_cuenta, 'X') = 'X')
            AND (tip_cuenta = p_tip_cuenta OR nvl(tip_cuenta, 'X') = 'X')
            AND (tip_interes = p_tip_interes OR nvl(tip_interes, 'X') = 'X')
            AND (tip_renovacion = p_tip_renovacion OR nvl(tip_renovacion, 'X') = 'X')
            AND (cat_automatica = v_cat_automatica OR nvl(cat_automatica, -1) = -1)
            AND tip_movimiento = p_tip_movimiento;
      END IF;
      IF v_ind_plazo = 'S' THEN
         p_cod_rubro := substr(p_cod_rubro, 1, 2) || v_cod_plazo || substr(p_cod_rubro, 4, 12);
      END IF;
      IF v_ind_deudor = 'S' OR substr(p_cod_rubro, 9, 2) = 'TD' THEN
         p_cod_rubro := substr(p_cod_rubro, 1, 8) || (ltrim(to_char(v_cod_tip_deudor, '00'))) ||
                        substr(p_cod_rubro, 11, 5);
      END IF;
      ---Reemplaza el codigo del producto -----------------------
      IF v_ind_producto = 'S' THEN
         p_cod_rubro := substr(p_cod_rubro, 1, 10) || ltrim(to_char(v_cod_pro_contable, '000')) ||
                        substr(p_cod_rubro, 14, 2);
      END IF;
      IF substr(p_cod_rubro, 11, 3) = 'SEC' THEN
         -- es solo para prestamos, para contabilizar por sector
         p_cod_rubro := substr(p_cod_rubro, 1, 10) || ltrim(to_char(fup_obt_sec_rubro(p_cod_sec_credito), '000')) ||
                        substr(p_cod_rubro, 14, 2);
      END IF;
      RETURN p_cod_rubro;
   EXCEPTION
      WHEN OTHERS THEN
         p_cod_rubro := NULL;
         RETURN p_cod_rubro;
   END;

   FUNCTION fu_obt_cod_entidad RETURN NUMBER IS
      result ge_par_generales.cod_entidad%TYPE;
   BEGIN
      -- Obtiene el Codigo de Entidad
      SELECT cod_entidad
        INTO result
        FROM ge_par_generales
       WHERE rownum = 1;

      RETURN(result);
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'FUG OBT COD ENTIDAD ' || SQLERRM);
   END;
   -- Funcion para obtener el codigo del banco central.
   FUNCTION fu_obt_cod_bcp(p_cod_rub_economico VARCHAR2) RETURN VARCHAR2 IS
      v_cod_bco_central pr_rub_economicos.cod_bco_central%TYPE;
   BEGIN
      SELECT cod_bco_central
        INTO v_cod_bco_central
        FROM pr_rub_economicos
       WHERE cod_rub_economico = p_cod_rub_economico;

      RETURN v_cod_bco_central;
   EXCEPTION
      WHEN OTHERS THEN
         RETURN NULL;
   END;
   --- Funcion que retorna si la Operacion es valida para envio a CRC
   FUNCTION fu_pue_env_bcp(p_tip_operacion IN VARCHAR2) RETURN VARCHAR2 IS
      v_tip_operacion VARCHAR2(1) := 'N';
   BEGIN
      -- Obtiene el Codigo de Entidad
      SELECT decode(v_cod_entidad, '1007', 'S', 6004, 'S', decode(nvl(COUNT(*), 0), 0, 'N', 'S'))
        INTO v_tip_operacion
        FROM ba_cod_referencias b
       WHERE b.dominio = 'TIP_OPE_INF_CRC'
         AND b.val_minimo = p_tip_operacion;
      RETURN(v_tip_operacion);
   EXCEPTION
      WHEN OTHERS THEN
         RETURN NULL;
   END;
    FUNCTION fu_ope_existe
    (
      p_nro_operacion in sb_crc_operaciones_det.nro_operacion%TYPE,
      p_tip_operacion in sb_crc_operaciones_det.tip_operacion%TYPE
    ) RETURN VARCHAR2 IS
      v_existe VARCHAR2(1) := 'N';
    BEGIN
      -- Obtiene el Codigo de Entidad
      SELECT DISTINCT 'S'
        INTO v_existe
        FROM sb_crc_operaciones_det b
       WHERE tip_operacion = p_tip_operacion
         AND nro_operacion = p_nro_operacion;
    RETURN(v_existe);
    EXCEPTION
      WHEN OTHERS THEN
         RETURN 'N';
    END;
   --- Funcion que retorna si el Ruc sera enviado en forma diaria para envio a CRC
   FUNCTION fu_ruc_sal_diario(p_nro_cuenta IN VARCHAR2) RETURN VARCHAR2 IS
      v_enviar VARCHAR2(1) := 'N';
   BEGIN
    SELECT 'S'
      INTO v_enviar
      FROM ba_cod_referencias b, ba_personas p, ge_cta_clientes g
     WHERE b.dominio = 'SIB_RUC_CLI_CRC_SALDOS'
       AND p.nro_documento = b.val_minimo
       AND g.nro_cuenta = p_nro_cuenta
       AND to_number(g.cod_persona) = p.cod_persona
       AND g.relacion = 'P'
    UNION
     SELECT 'S'
      FROM ge_che_custodias v, pr_rel_chq_lib rel
     WHERE v.nro_referencia = p_nro_cuenta
     AND rel.nro_cheque = v.nro_cheque
     AND rel.cod_banco = v.cod_banco
     AND rel.cta_libradora = v.cta_libradora
       AND EXISTS (SELECT 1
              FROM pr_chq_libradores lib, ba_cod_referencias q
             WHERE lib.nro_documento = q.val_minimo
               and q.dominio = 'SIB_RUC_CLI_CRC_SALDOS'
               and lib.nro_documento = rel.nro_documento
                     );
    /*SELECT 'S'
      FROM ge_che_custodias v
     WHERE v.nro_referencia = p_nro_cuenta
       AND EXISTS (SELECT 1
              FROM pr_chq_libradores lib, pr_rel_chq_lib rel
             WHERE lib.nro_documento = rel.nro_documento
               AND rel.nro_cheque = v.nro_cheque
               AND rel.cod_banco = v.cod_banco
               AND rel.cta_libradora = v.cta_libradora
               AND lib.nro_documento IN
                   (SELECT q.val_minimo
                      FROM ba_cod_referencias q
                     WHERE q.dominio = 'SIB_RUC_CLI_CRC_SALDOS'
                     ));*/
      RETURN(v_enviar);
   EXCEPTION
      WHEN no_data_found THEN
         RETURN 'N';
      WHEN OTHERS THEN
         RETURN 'N';
   END;

   FUNCTION fu_obt_reg_vinculo(p_fec_periodo IN DATE, p_nom_referencia IN VARCHAR2) RETURN NUMBER IS
      v_can_registros number;
   BEGIN
      SELECT MAX(nro_registro)
        INTO v_can_registros
        FROM sb_crc_vinculos_det
       WHERE fecha = p_fec_periodo;
      return v_can_registros;
   EXCEPTION
      WHEN OTHERS THEN
         return null;
   END;

   -- Devuelve la sigte. fecha de vencimiento de la procesadora con relacion a la fecha ingresada.
   FUNCTION fu_obt_sig_fec_vencimiento(p_cod_procesadora IN NUMBER,
                                       p_cod_modalidad   IN NUMBER,
                                       p_fecha           IN DATE,
                                       p_cod_tip_cierre  IN NUMBER DEFAULT 1) RETURN DATE IS
      v_fecha DATE;
   BEGIN
      BEGIN
         SELECT fec_vencimiento
           INTO v_fecha
           FROM ta_cal_cierres
          WHERE cod_ent_procesadora = p_cod_procesadora
            AND cod_modulo = 5
            AND cod_modalidad = p_cod_modalidad
            AND cod_tip_cierre = p_cod_tip_cierre
            AND fec_cierre = (SELECT MIN(fec_cierre)
                                FROM ta_cal_cierres
                               WHERE cod_ent_procesadora = p_cod_procesadora
                                 AND cod_modulo = 5
                                 AND cod_modalidad = p_cod_modalidad
                                 AND cod_tip_cierre = p_cod_tip_cierre
                                 AND fec_cierre > p_fecha);
      EXCEPTION
         WHEN no_data_found THEN
            SELECT fec_vencimiento
              INTO v_fecha
              FROM ta_cal_cierres
             WHERE cod_ent_procesadora = p_cod_procesadora
               AND cod_modulo = 5
               AND cod_modalidad IS NULL
               AND cod_tip_cierre = p_cod_tip_cierre
               AND fec_cierre = (SELECT MIN(fec_cierre)
                                   FROM ta_cal_cierres
                                  WHERE cod_ent_procesadora = p_cod_procesadora
                                    AND cod_modulo = 5
                                    AND cod_modalidad IS NULL
                                    AND cod_tip_cierre = p_cod_tip_cierre
                                    AND fec_cierre > p_fecha);
      END;
      RETURN v_fecha;
   EXCEPTION
      WHEN no_data_found THEN
         RETURN NULL;
      WHEN OTHERS THEN
         RETURN NULL;
   END;

   -- Funcion para obtener el codigo de departamento del banco central a partir del codigo de departamento
   FUNCTION fu_obt_ref_bco_central(p_cod_departamento ba_departamentos.cod_departamento%TYPE) RETURN VARCHAR2 IS
      v_ref_bco_central ba_departamentos.ref_bco_central%TYPE;
   BEGIN
      SELECT ref_bco_central
        INTO v_ref_bco_central
        FROM ba_departamentos
       WHERE cod_departamento = p_cod_departamento;
      RETURN v_ref_bco_central;
   EXCEPTION
      WHEN no_data_found THEN
         RETURN NULL;
      WHEN OTHERS THEN
         RETURN NULL;
   END;
   FUNCTION fu_obt_cod_dep_destino(p_nro_cuenta ge_cuentas.nro_cuenta%TYPE, p_nom_tabla VARCHAR2) RETURN NUMBER IS
      TYPE t_tipo_cursor IS REF CURSOR;
      c_cursor           t_tipo_cursor;
      v_cod_departamento ba_departamentos.cod_departamento%TYPE;
      v_sql              VARCHAR2(2000);
   BEGIN
      v_sql := 'select cod_departamento from ' || p_nom_tabla || ' where nro_cuenta = ' || '''' || p_nro_cuenta || '''';
      OPEN c_cursor FOR v_sql;
      LOOP
         FETCH c_cursor
            INTO v_cod_departamento;
         EXIT WHEN c_cursor%NOTFOUND;
      END LOOP;
      RETURN v_cod_departamento;
   EXCEPTION
      WHEN OTHERS THEN
         RETURN NULL;
   END;
   -- Funcion para obtener referencia de garantia banco central.
   FUNCTION fu_obt_ref_gar_bco_central(p_cod_garantia pr_gar_tipos.cod_garantia%TYPE) RETURN NUMBER IS
      v_cod_ref_bco_central pr_gar_tipos.cod_ref_bco_central%TYPE;
   BEGIN
      SELECT c.cod_ref_bco_central
        INTO v_cod_ref_bco_central
        FROM pr_gar_tipos c
       WHERE c.cod_garantia = p_cod_garantia;
      RETURN v_cod_ref_bco_central;
   EXCEPTION
      WHEN OTHERS THEN
         RETURN NULL;
   END;
    -- Funci?n para obtener el valor del tipo de operaci?n.
   FUNCTION fu_obt_tip_operacion( p_tip_operacion IN sb_crc_saldos_det.rub_con_capital%TYPE,
                                  p_domino        IN ba_cod_referencias.dominio%TYPE ) RETURN VARCHAR2 IS
      v_es_tip_operacion VARCHAR2(1) := 'N';
   BEGIN
      SELECT decode(nvl(COUNT(*), 0), 0, 'N', 'S')
        INTO v_es_tip_operacion
        FROM ba_cod_referencias x
       WHERE x.dominio = p_domino
         AND x.val_minimo = p_tip_operacion;
      RETURN(v_es_tip_operacion);
   EXCEPTION
      WHEN OTHERS THEN
         RETURN 'S';
   END;
    -- Funci?n para obtener el monto pignorado
   FUNCTION fu_obt_mto_pignorado( p_cod_modalidad  IN ge_modalidades.cod_modalidad%TYPE,
                                  p_nro_cuenta     IN ge_cuentas.nro_cuenta%TYPE ) RETURN NUMBER IS
     v_cod_cau_blo_garan     ge_bloqueos.cod_causa%TYPE := fug_obt_pardinamico('COD_CAU_BLO_GARAN');
     v_mto_pignorado         ge_bloqueos.monto%TYPE := 0;
   BEGIN
      IF p_cod_modalidad <> 36 THEN
         SELECT nvl(SUM(v.monto), 0) monto
           INTO v_mto_pignorado
           FROM (SELECT DISTINCT gb.*
                   FROM pr_gar_cash      c,
                        pr_cta_garantias g,
                        pr_cta_prestamos pr,
                        pr_garantias     ga,
                        ge_bloqueos      gb
                  WHERE c.nro_garantia = g.nro_garantia
                    AND g.nro_cuenta = pr.nro_cuenta
                    AND ga.nro_garantia = c.nro_garantia
                    AND pr.estado != 'N'
                    AND ga.estado IN ('C', 'V', 'N', 'T')
                    AND c.nro_cta_referencia = gb.nro_cuenta
                    AND gb.cod_causa = v_cod_cau_blo_garan
                    AND c.nro_cta_referencia = p_nro_cuenta) v;
         IF v_mto_pignorado <= 0 THEN
            SELECT nvl(SUM(v.monto), 0) monto
              INTO v_mto_pignorado
              FROM (SELECT DISTINCT gb.*
                      FROM pr_gar_cash c, pr_garantias ga, ge_bloqueos gb
                     WHERE ga.nro_garantia = c.nro_garantia
                       AND ga.estado IN ('C', 'V', 'N', 'T')
                       AND c.nro_cta_referencia = gb.nro_cuenta
                       AND gb.cod_causa = v_cod_cau_blo_garan
                       AND c.nro_cta_referencia = p_nro_cuenta) v;
         END IF;
         IF v_mto_pignorado <= 0 THEN
            SELECT nvl(SUM(v.monto), 0) monto
              INTO v_mto_pignorado
              FROM (SELECT DISTINCT gb.*
                      FROM ge_bloqueos gb
                     WHERE gb.cod_causa = v_cod_cau_blo_garan
                       AND NOT EXISTS
                     (SELECT 1 FROM pr_gar_cash m WHERE m.nro_cta_referencia = gb.nro_cuenta)
                       AND gb.nro_cuenta = p_nro_cuenta) v;
         END IF;
      ELSE
        SELECT nvl(SUM(v.monto), 0)
           INTO v_mto_pignorado
           FROM (SELECT DISTINCT c.*
                   FROM pr_gar_cash c, pr_cta_garantias g, pr_cta_prestamos pr, pr_garantias ga
                  WHERE c.nro_garantia = g.nro_garantia
                    AND g.nro_cuenta = pr.nro_cuenta
                    AND ga.nro_garantia = c.nro_garantia
                    AND pr.estado != 'N'
                    AND ga.estado = 'C'
                    AND c.nro_cta_referencia = p_nro_cuenta) v;
      END IF;
      RETURN v_mto_pignorado;
   EXCEPTION
     WHEN OTHERS THEN
       RETURN 0;
   END;
   FUNCTION fu_obt_rub_con_tipo
   (
      p_nro_cuenta IN VARCHAR2,
      p_tip_saldo  IN VARCHAR2,
      p_tip_ope    IN VARCHAR2,
      p_sit_deuda  IN VARCHAR2 DEFAULT NULL
   ) RETURN VARCHAR2 IS
      v_cod_rubro cb_rubros.cod_rubro%TYPE;
   BEGIN
      SELECT a.cod_rubro
        INTO v_cod_rubro
        FROM cb_sal_inventarios a, cb_sal_inventarios_det d
       WHERE a.nro_referencia = d.nro_referencia
         AND d.nro_cuenta = p_nro_cuenta
         AND a.tip_saldo = p_tip_saldo
         AND substr(a.cod_rubro, 6, 3) = p_tip_ope
         AND (p_sit_deuda IS NULL OR a.situacion = p_sit_deuda);
      RETURN v_cod_rubro;
   EXCEPTION
      WHEN OTHERS THEN
         RETURN NULL;
   END;
   FUNCTION fu_obt_operacion(p_nro_operacion sb_crc_operaciones_det.nro_operacion%TYPE,
                             p_tipo      number) RETURN VARCHAR2 IS
      v_operacion sb_crc_ope_garantias_det.nro_operacion%TYPE;
   BEGIN
     IF p_tipo = 1 THEN
        BEGIN
           SELECT decode(instr(p_nro_operacion, '-'), 0, (decode(instr(p_nro_operacion, '#'),0, p_nro_operacion,
                              substr(p_nro_operacion, 1, instr(p_nro_operacion, '#')-1))), substr(p_nro_operacion, 1, instr(p_nro_operacion, '-')-1))
             INTO v_operacion
             FROM dual;
           RETURN v_operacion;
        END;
     ELSIF p_tipo = 2 THEN
        BEGIN
           SELECT decode(instr(p_nro_operacion, '-'), 0, NULL, substr(p_nro_operacion, instr(p_nro_operacion, '-')+1, 4))
             INTO v_operacion
             FROM dual;
           RETURN v_operacion;
        END;
     ELSIF p_tipo = 3 THEN
        BEGIN
           SELECT (decode(instr(p_nro_operacion, '#'),0, null,
           substr(p_nro_operacion, instr(p_nro_operacion, '#',1,1)+1,instr(p_nro_operacion, '#',1,2)-instr(p_nro_operacion, '#',1,1)-1)))
           INTO v_operacion
             FROM dual;
           RETURN v_operacion;
        END;

     END IF;
   EXCEPTION
      WHEN OTHERS THEN
         RETURN NULL;
   END;
   -- Procedimiento de insercion de Garantias
   PROCEDURE lp_ins_garantias_det(rp_scgde sb_crc_garantias_det%ROWTYPE) IS
      v_cot_mto_seguro ge_cotizaciones.val_conversion%TYPE;
   BEGIN
      IF rp_scgde.cod_mon_iso_garantia <> v_cod_mon_local THEN
         v_cotizacion := nvl(fug_obt_cotizacion(rp_scgde.cod_mon_iso_garantia, rp_scgde.fec_valor), 1);
      ELSE
         v_cotizacion := 1;
      END IF;

      IF rp_scgde.cod_mon_iso_seguro <> v_cod_mon_local THEN
         v_cot_mto_seguro := nvl(fug_obt_cotizacion(rp_scgde.cod_mon_iso_seguro, rp_scgde.fec_valor), 1);
      ELSE
         v_cot_mto_seguro := 1;
      END IF;

      INSERT INTO sb_crc_garantias_det
         (fecha,
          nom_referencia,
          nro_formulario,
          cod_oficina,
          cod_mon_iso_garantia,
          nro_garantia,
          cod_ref_bco_central,
          nro_inscripcion,
          rango,
          fec_valor,
          fec_vencimiento,
          mto_garantia,
          fec_ini_tasacion,
          fec_vto_tasacion,
          mto_tas_asegurable,
          mto_tas_no_asegurable,
          fec_ini_seguro,
          fec_vto_seguro,
          cod_mon_iso_seguro,
          mto_asegurado,
          tip_gar_especifica,
          perfeccionada,
          nro_registro,
          cod_persona,
          est_garantia,
          fec_confirmacion,
          mto_gar_equ_local,
          mto_seg_equ_local,
          mto_tas_ase_equ_local,
          mto_tas_no_ase_equ_local)
      VALUES
         (rp_scgde.fecha,
          rp_scgde.nom_referencia,
          rp_scgde.nro_formulario,
          nvl(fug_obt_pardinamico('COD_OFI_NO_HAB_BCP', NULL, NULL, NULL, rp_scgde.cod_oficina), rp_scgde.cod_oficina),
          fu_obt_mon_iso(rp_scgde.cod_mon_iso_garantia),
          rp_scgde.nro_garantia,
          rp_scgde.cod_ref_bco_central,
          rp_scgde.nro_inscripcion,
          rp_scgde.rango,
          rp_scgde.fec_valor,
          rp_scgde.fec_vencimiento,
          rp_scgde.mto_garantia,
          rp_scgde.fec_ini_tasacion,
          rp_scgde.fec_vto_tasacion,
          rp_scgde.mto_tas_asegurable,
          rp_scgde.mto_tas_no_asegurable,
          NVL(rp_scgde.fec_ini_seguro, rp_scgde.fec_valor),
          NVL(rp_scgde.fec_vto_seguro, rp_scgde.fec_vencimiento),
          fu_obt_mon_iso(NVL(rp_scgde.cod_mon_iso_seguro, rp_scgde.cod_mon_iso_garantia)),
          rp_scgde.mto_asegurado,
          rp_scgde.tip_gar_especifica,
          rp_scgde.perfeccionada,
          rp_scgde.nro_registro,
          rp_scgde.cod_persona,
          rp_scgde.est_garantia,
          rp_scgde.fec_confirmacion,
          round(rp_scgde.mto_gar_equ_local * v_cotizacion, v_redondeo),
          round(rp_scgde.mto_seg_equ_local * v_cot_mto_seguro, v_redondeo),
          round(rp_scgde.mto_tas_ase_equ_local * v_cot_mto_seguro, v_redondeo),
          round(rp_scgde.mto_tas_no_ase_equ_local * v_cot_mto_seguro, v_redondeo));
   END;
   -- Procedimiento que obtiene los datos de las Garantias
   PROCEDURE lp_obt_dat_garantia_det(p_nro_garantia          IN sb_crc_garantias_det.nro_garantia%TYPE,
                                     p_nom_tab_anexa         IN pr_gar_tipos.nom_tab_anexa%TYPE,
                                     p_mto_tas_asegurable    OUT sb_crc_garantias_det.mto_tas_asegurable%TYPE,
                                     p_mto_tas_no_asegurable OUT sb_crc_garantias_det.mto_tas_no_asegurable%TYPE,
                                     p_mto_asegurado         OUT sb_crc_garantias_det.mto_asegurado%TYPE,
                                     p_fec_ini_tasacion      OUT sb_crc_garantias_det.fec_ini_tasacion%TYPE,
                                     p_fec_vto_tasacion      OUT sb_crc_garantias_det.fec_vto_tasacion%TYPE,
                                     p_nro_inscripcion       OUT sb_crc_garantias_det.nro_inscripcion%TYPE,
                                     p_fec_ini_seguro        OUT sb_crc_garantias_det.fec_ini_seguro%TYPE,
                                     p_fec_vto_seguro        OUT sb_crc_garantias_det.fec_vto_seguro%TYPE,
                                     p_cod_mon_tasacion      OUT sb_crc_garantias_det.cod_mon_iso_seguro%TYPE) IS

      v_fec_inscripcion pr_gar_hipotecarias.fec_inscripcion%TYPE;
      v_cod_ent_seguro  pr_garantias.cod_ent_seguro%TYPE;
   BEGIN
      BEGIN
         SELECT sum(det.mto_tas_asegurable), sum(det.mto_tas_no_asegurable), sum(det.mto_asegurado),
                det.cod_mon_tasacion
           INTO p_mto_tas_asegurable, p_mto_tas_no_asegurable, p_mto_asegurado, p_cod_mon_tasacion
           FROM sv_garantias_det det
          WHERE det.nro_garantia = p_nro_garantia
          GROUP BY det.nro_garantia, det.cod_mon_tasacion;
      EXCEPTION
         WHEN OTHERS THEN
            p_mto_tas_asegurable    := NULL;
            v_mensaje               := v_mensaje || ', Monto Tasa Asegurable es nulo';
            p_mto_tas_no_asegurable := NULL;
            v_mensaje               := v_mensaje || ', Monto Tasa no Asegurable es nulo';
            p_mto_asegurado         := NULL;
            v_mensaje               := v_mensaje || ', Monto Asegurado es nulo';
      END;
      --- Para Garantias Hipotecarias
      IF p_nom_tab_anexa = 'PR_GAR_HIPOTECARIAS' THEN
         BEGIN
            SELECT MAX(h.fec_ult_tasacion)
              INTO p_fec_ini_tasacion
              FROM pr_gar_hipotecarias h
             WHERE h.nro_garantia = p_nro_garantia
               AND h.fec_ult_tasacion <= v_fec_fin;
         EXCEPTION
            WHEN OTHERS THEN
               p_fec_ini_tasacion := NULL;
         END;
         BEGIN
            SELECT MAX(h.fec_vencimiento)
              INTO p_fec_vto_tasacion
              FROM pr_gar_hipotecarias h
             WHERE nro_garantia = p_nro_garantia
               AND h.fec_vencimiento >= v_fec_fin;
         EXCEPTION
            WHEN OTHERS THEN
               p_fec_vto_tasacion := NULL;
         END;
         BEGIN
            SELECT MAX(h.fec_vto_seguro)
              INTO p_fec_vto_seguro
              FROM pr_gar_hipotecarias h
             WHERE h.nro_garantia = p_nro_garantia
               AND h.fec_vto_seguro >= v_fec_fin;
         EXCEPTION
            WHEN OTHERS THEN
               p_fec_vto_seguro := NULL;
         END;
         BEGIN
            SELECT MAX(h.fec_ini_seguro), MAX(h.cod_ent_seguro)
              INTO p_fec_ini_seguro, v_cod_ent_seguro
              FROM pr_gar_hipotecarias h
             WHERE h.nro_garantia = p_nro_garantia
               AND h.fec_ini_seguro <= v_fec_fin;
         EXCEPTION
            WHEN OTHERS THEN
               p_fec_ini_seguro := NULL;
               v_cod_ent_seguro := NULL;
         END;
         BEGIN
            SELECT MAX(h.fec_inscripcion)
              INTO v_fec_inscripcion
              FROM pr_gar_hipotecarias h
             WHERE h.nro_garantia = p_nro_garantia
               AND h.fec_inscripcion <= v_fec_fin;
         EXCEPTION
            WHEN OTHERS THEN
               v_fec_inscripcion := NULL;
         END;
         BEGIN
            SELECT MAX(h.nro_inscripcion)
              INTO p_nro_inscripcion
              FROM pr_gar_hipotecarias h
             WHERE h.nro_garantia = p_nro_garantia
               AND h.fec_inscripcion = v_fec_inscripcion;
         EXCEPTION
            WHEN OTHERS THEN
               p_nro_inscripcion := NULL;
         END;
      END IF;
      --- Para Garantias Prendarias
      IF p_nom_tab_anexa = 'PR_GAR_VEHICULOS' THEN
         BEGIN
            SELECT MAX(h.fec_inicio)
              INTO p_fec_ini_tasacion
              FROM pr_gar_vehiculos h
             WHERE h.nro_garantia = p_nro_garantia
               AND h.fec_inicio <= v_fec_fin;
         EXCEPTION
            WHEN OTHERS THEN
               p_fec_ini_tasacion := NULL;
         END;
         BEGIN
            SELECT MAX(h.fec_vencimiento)
              INTO p_fec_vto_tasacion
              FROM pr_gar_vehiculos h
             WHERE h.nro_garantia = p_nro_garantia
               AND h.fec_vencimiento >= v_fec_fin;
         EXCEPTION
            WHEN OTHERS THEN
               p_fec_vto_tasacion := NULL;
         END;
         BEGIN
            SELECT MAX(h.fec_vto_seguro)
              INTO p_fec_vto_seguro
              FROM pr_gar_vehiculos h
             WHERE h.nro_garantia = p_nro_garantia
               AND h.fec_vto_seguro >= v_fec_fin;
         EXCEPTION
            WHEN OTHERS THEN
               p_fec_vto_seguro := NULL;
         END;
         BEGIN
            SELECT MAX(h.fec_ini_seguro), MAX(h.cod_ent_seguro)
              INTO p_fec_ini_seguro, v_cod_ent_seguro
              FROM pr_gar_vehiculos h
             WHERE h.nro_garantia = p_nro_garantia
               AND h.fec_ini_seguro <= v_fec_fin;
         EXCEPTION
            WHEN OTHERS THEN
               p_fec_ini_seguro := NULL;
               v_cod_ent_seguro := NULL;
         END;
         BEGIN
            SELECT MAX(h.fec_inscripcion)
              INTO v_fec_inscripcion
              FROM pr_gar_vehiculos h
             WHERE h.nro_garantia = p_nro_garantia
               AND h.fec_inscripcion <= v_fec_fin;
         EXCEPTION
            WHEN OTHERS THEN
               v_fec_inscripcion := NULL;
         END;
         BEGIN
            SELECT MAX(h.nro_inscripcion)
              INTO p_nro_inscripcion
              FROM pr_gar_vehiculos h
             WHERE h.nro_garantia = p_nro_garantia
               AND h.fec_inscripcion = v_fec_inscripcion;
         EXCEPTION
            WHEN OTHERS THEN
               p_nro_inscripcion := NULL;
         END;
      END IF;
      --- Para Garantias Cash
      IF p_nom_tab_anexa = 'PR_GAR_CASH' THEN
         BEGIN
            SELECT MAX(b.fec_inicio)
              INTO p_fec_ini_tasacion
              FROM pr_gar_cash b
             WHERE b.nro_garantia = p_nro_garantia
               AND b.fec_inicio <= v_fec_fin;
         EXCEPTION
            WHEN OTHERS THEN
               p_fec_ini_tasacion := NULL;
         END;
         BEGIN
            SELECT MAX(b.fec_vencimiento)
              INTO p_fec_vto_tasacion
              FROM pr_gar_cash b
             WHERE b.nro_garantia = p_nro_garantia
               AND b.fec_vencimiento >= v_fec_fin;
         EXCEPTION
            WHEN OTHERS THEN
               p_fec_vto_tasacion := NULL;
         END;
         ---- El resto de los campos no mencionados no posee una garantia Cash
      END IF;
      --- Para Garantias Warrants
      IF p_nom_tab_anexa = 'PR_GAR_WARRANTS' THEN
         BEGIN
            SELECT MAX(a.fec_inicio)
              INTO p_fec_ini_tasacion
              FROM pr_gar_warrants a
             WHERE a.nro_garantia = p_nro_garantia
               AND a.fec_inicio <= v_fec_fin;
         EXCEPTION
            WHEN OTHERS THEN
               p_fec_ini_tasacion := NULL;
         END;
         BEGIN
            SELECT MAX(a.fec_vencimiento)
              INTO p_fec_vto_tasacion
              FROM pr_gar_warrants a
             WHERE a.nro_garantia = p_nro_garantia
               AND a.fec_vencimiento >= v_fec_fin;
         EXCEPTION
            WHEN OTHERS THEN
               p_fec_vto_tasacion := NULL;
         END;
         BEGIN
            SELECT MAX(a.fec_ini_seguro), MAX(a.cod_ent_seguro)
              INTO p_fec_ini_seguro, v_cod_ent_seguro
              FROM pr_gar_warrants a
             WHERE a.nro_garantia = p_nro_garantia
               AND a.fec_ini_seguro <= v_fec_fin;
         EXCEPTION
            WHEN OTHERS THEN
               p_fec_ini_seguro := NULL;
               v_cod_ent_seguro := NULL;
         END;
         BEGIN
            SELECT MAX(a.fec_vto_seguro)
              INTO p_fec_vto_seguro
              FROM pr_gar_warrants a
             WHERE a.nro_garantia = p_nro_garantia
               AND a.fec_vto_seguro >= v_fec_fin;
         EXCEPTION
            WHEN OTHERS THEN
               p_fec_vto_seguro := NULL;
         END;
         ---- El resto de los campos no mencionados no posee una garantia Warrants
      END IF;
      --- Para Garantias Standbys
      IF p_nom_tab_anexa = 'PR_GAR_STANDBYS' THEN
         BEGIN
            SELECT MAX(b.fec_inicio)
              INTO p_fec_ini_tasacion
              FROM pr_gar_standbys b
             WHERE b.nro_garantia = p_nro_garantia
               AND b.fec_inicio <= v_fec_fin;
         EXCEPTION
            WHEN OTHERS THEN
               p_fec_ini_tasacion := NULL;
         END;
         BEGIN
            SELECT MAX(b.fec_vencimiento)
              INTO p_fec_vto_tasacion
              FROM pr_gar_standbys b
             WHERE b.nro_garantia = p_nro_garantia
               AND b.fec_vencimiento >= v_fec_fin;
         EXCEPTION
            WHEN OTHERS THEN
               p_fec_vto_tasacion := NULL;
         END;
         ---- El resto de los campos no mencionados no posee una garantia Standby
      END IF;
      IF p_fec_vto_tasacion IS NULL THEN
         v_mensaje := v_mensaje || ', Fecha Vto. tasacion es nulo';
      END IF;
      IF p_fec_ini_tasacion IS NULL THEN
         v_mensaje := v_mensaje || ', Fecha Inicio tasacion es nulo';
      END IF;
      IF p_nom_tab_anexa IN ('PR_GAR_VEHICULOS', 'PR_GAR_HIPOTECARIAS', 'PR_GAR_WARRANTS') THEN
         IF v_cod_ent_seguro IS NULL AND (p_fec_vto_seguro IS NOT NULL OR p_fec_ini_seguro IS NOT NULL) THEN
            v_mensaje := v_mensaje || ', Codigo de Aseguradora es Nulo';
         ELSIF v_cod_ent_seguro IS NOT NULL AND (p_fec_vto_seguro IS NULL OR p_fec_ini_seguro IS NULL) THEN
            IF p_fec_vto_seguro IS NULL THEN
               v_mensaje := v_mensaje || ', Fecha Vto. Seguro es nulo';
            END IF;
            IF p_fec_ini_seguro IS NULL THEN
               v_mensaje := v_mensaje || ', Fecha Inicio Seguro es nulo';
            END IF;
         END IF;
      END IF;
      IF p_nom_tab_anexa IN ('PR_GAR_VEHICULOS', 'PR_GAR_HIPOTECARIAS') THEN
         IF p_nro_inscripcion IS NULL THEN
            v_mensaje := v_mensaje || ', Nro. de Inscripcion es nulo';
         END IF;
         IF v_fec_inscripcion IS NULL THEN
            v_mensaje := v_mensaje || ', Fecha Inscripcion es nulo';
         END IF;
      END IF;
   END;
   -- Obtiene el valor del campo perfeccionada de la tabla sb_crc_garantias_det
   FUNCTION fu_obt_gar_perfeccionada(p_nro_garantia IN sb_crc_garantias_nov.nro_garantia%TYPE,
                                     p_cod_persona  IN sb_crc_garantias_nov.cod_persona%TYPE) RETURN VARCHAR2 IS
      v_perfeccionada sb_crc_garantias_nov.perfeccionada%TYPE;
   BEGIN
      SELECT perfeccionada
        INTO v_perfeccionada
        FROM sb_crc_garantias_det
       WHERE nro_garantia = p_nro_garantia
         AND cod_persona = p_cod_persona;
      RETURN v_perfeccionada;
   EXCEPTION
      WHEN OTHERS THEN
         RETURN NULL;
   END;
   FUNCTION lf_ver_nov_fec_valor(p_fec_valor    sb_crc_garantias_det.fec_valor%TYPE,
                                 p_nro_garantia sb_crc_garantias_det.nro_garantia%TYPE) RETURN VARCHAR2 IS
      v_fec_valor     sb_crc_garantias_det.fec_valor%TYPE;
      v_gar_fec_valor sb_crc_garantias_det.fec_valor%TYPE;
      v_nov_fec_valor VARCHAR2(1) := 'N';
   BEGIN
      SELECT fec_valor
        INTO v_fec_valor
        FROM sb_crc_garantias_det g
       WHERE g.nro_garantia = p_nro_garantia
         AND fecha = (SELECT MIN(fecha)
                        FROM sb_crc_garantias_det d
                       WHERE d.nro_garantia = p_nro_garantia);
      SELECT fec_valor
        INTO v_gar_fec_valor
        FROM sb_crc_garantias_det g
       WHERE g.nro_garantia = p_nro_garantia
         AND fecha = (SELECT MAX(fecha)
                        FROM sb_crc_garantias_det d
                       WHERE d.nro_garantia = p_nro_garantia);

      IF nvl(p_fec_valor, to_date('01/01/1900', 'dd/mm/yyyy')) <> nvl(v_fec_valor, to_date('01/01/1900', 'dd/mm/yyyy')) AND
         nvl(p_fec_valor, to_date('01/01/1900', 'dd/mm/yyyy')) <>
         nvl(v_gar_fec_valor, to_date('01/01/1900', 'dd/mm/yyyy')) THEN
         v_nov_fec_valor := 'S';
         RETURN v_nov_fec_valor;
      END IF;
      RETURN v_nov_fec_valor;
   EXCEPTION
      WHEN OTHERS THEN
         v_nov_fec_valor := 'N';
         RETURN v_nov_fec_valor;
   END;
   FUNCTION lf_ver_nov_garantia(rp_scgde sb_crc_garantias_det%ROWTYPE) RETURN VARCHAR2 IS
      v_cod_mon_iso_garantia  sb_crc_garantias_det.cod_mon_iso_garantia%TYPE;
      v_nro_inscripcion       sb_crc_garantias_det.nro_inscripcion%TYPE;
      v_rango                 sb_crc_garantias_det.rango%TYPE;
      v_fec_valor             sb_crc_garantias_det.fec_valor%TYPE;
      v_fec_vencimiento       sb_crc_garantias_det.fec_vencimiento%TYPE;
      v_mto_garantia          sb_crc_garantias_det.mto_garantia%TYPE;
      v_fec_ini_tasacion      sb_crc_garantias_det.fec_ini_tasacion%TYPE;
      v_fec_vto_tasacion      sb_crc_garantias_det.fec_vto_tasacion%TYPE;
      v_mto_tas_asegurable    sb_crc_garantias_det.mto_tas_asegurable%TYPE;
      v_mto_tas_no_asegurable sb_crc_garantias_det.mto_tas_no_asegurable%TYPE;
      v_fec_ini_seguro        sb_crc_garantias_det.fec_ini_seguro%TYPE;
      v_fec_vto_seguro        sb_crc_garantias_det.fec_vto_seguro%TYPE;
      v_mto_asegurado         sb_crc_garantias_det.mto_asegurado%TYPE;
      v_tip_gar_especifica    sb_crc_garantias_det.tip_gar_especifica%TYPE;
      v_perfeccionada         sb_crc_garantias_det.perfeccionada%TYPE;
      v_novedad               VARCHAR2(1) := 'N';
   BEGIN
      SELECT cod_mon_iso_garantia, nro_inscripcion, rango, fec_valor, fec_vencimiento, mto_garantia, fec_ini_tasacion,
             fec_vto_tasacion, mto_tas_asegurable, mto_tas_no_asegurable, fec_ini_seguro, fec_vto_seguro, mto_asegurado,
             tip_gar_especifica, perfeccionada
        INTO v_cod_mon_iso_garantia, v_nro_inscripcion, v_rango, v_fec_valor, v_fec_vencimiento, v_mto_garantia,
             v_fec_ini_tasacion, v_fec_vto_tasacion, v_mto_tas_asegurable, v_mto_tas_no_asegurable, v_fec_ini_seguro,
             v_fec_vto_seguro, v_mto_asegurado, v_tip_gar_especifica, v_perfeccionada
        FROM sb_crc_garantias_det g
       WHERE g.nro_garantia = rp_scgde.nro_garantia
         AND g.est_garantia = 'C'
         AND fecha = (SELECT MAX(fecha)
                        FROM sb_crc_garantias_det d
                       WHERE d.nro_garantia = rp_scgde.nro_garantia);
      IF NVL(fu_obt_mon_iso(rp_scgde.cod_mon_iso_garantia), ' ') <> NVL(v_cod_mon_iso_garantia, ' ') then
         v_novedad := 'S';
         return v_novedad;
      ELSIF NVL(rp_scgde.nro_inscripcion, ' ') <> NVL(v_nro_inscripcion, ' ') then
         v_novedad := 'S';
         return v_novedad;
      ELSIF NVL(rp_scgde.rango, 0) <> NVL(v_rango, 0) then
         v_novedad := 'S';
         return v_novedad;
      ELSIF lf_ver_nov_fec_valor(rp_scgde.fec_valor, rp_scgde.nro_garantia) = 'S' THEN
         v_novedad := 'S';
         return v_novedad;
      ELSIF NVL(rp_scgde.fec_vencimiento, to_date('01/01/1900', 'dd/mm/yyyy')) <>
            NVL(v_fec_vencimiento, to_date('01/01/1900', 'dd/mm/yyyy')) then
         v_novedad := 'S';
         return v_novedad;
      ELSIF NVL(rp_scgde.mto_garantia, 0) <> NVL(v_mto_garantia, 0) then
         v_novedad := 'S';
         return v_novedad;
      ELSIF NVL(rp_scgde.fec_ini_tasacion, to_date('01/01/1900', 'dd/mm/yyyy')) <>
            NVL(v_fec_ini_tasacion, to_date('01/01/1900', 'dd/mm/yyyy')) then
         v_novedad := 'S';
         return v_novedad;
      ELSIF NVL(rp_scgde.fec_vto_tasacion, to_date('01/01/1900', 'dd/mm/yyyy')) <>
            NVL(v_fec_vto_tasacion, to_date('01/01/1900', 'dd/mm/yyyy')) then
         v_novedad := 'S';
         return v_novedad;
      ELSIF NVL(rp_scgde.mto_tas_asegurable, 0) <> NVL(v_mto_tas_asegurable, 0) then
         v_novedad := 'S';
         return v_novedad;
      ELSIF NVL(rp_scgde.mto_tas_no_asegurable, 0) <> NVL(v_mto_tas_no_asegurable, 0) then
         v_novedad := 'S';
         return v_novedad;
      ELSIF NVL(rp_scgde.fec_ini_seguro, v_fec_valor) <> NVL(v_fec_ini_seguro, v_fec_valor) then
         v_novedad := 'S';
         return v_novedad;
      ELSIF NVL(rp_scgde.fec_vto_seguro, v_fec_vencimiento) <> NVL(v_fec_vto_seguro, v_fec_vencimiento) then
         v_novedad := 'S';
         return v_novedad;
      ELSIF NVL(rp_scgde.mto_asegurado, 0) <> NVL(v_mto_asegurado, 0) then
         v_novedad := 'S';
         return v_novedad;
      ELSIF NVL(rp_scgde.tip_gar_especifica, ' ') <> NVL(v_tip_gar_especifica, ' ') then
         v_novedad := 'S';
         return v_novedad;
      ELSIF NVL(rp_scgde.perfeccionada, ' ') <> NVL(v_perfeccionada, ' ') then
         v_novedad := 'S';
         return v_novedad;
      ELSE
         v_novedad := 'N';
         return v_novedad;
      END IF;
      IF rp_scgde.fec_valor > rp_scgde.fec_vencimiento THEN
         v_novedad := 'N';
         return v_novedad;
      END IF;

   EXCEPTION
      WHEN OTHERS THEN
         v_novedad := null;
         RETURN v_novedad;
   END;
   PROCEDURE pr_crc_gen_gar_novedades(p_nro_registro in sb_crc_garantias_det.nro_registro%TYPE) IS

      CURSOR c_gar_novedades IS
         SELECT t.cod_oficina, t.cod_moneda, t.nro_garantia, t.cod_garantia, t.ref_gar_bcp, t.rango, t.fec_inicio,
                t.fec_confirmacion, t.fec_vencimiento, t.valor, t.cod_mon_tasacion, t.tipo, t.perfeccionada,
                t.cod_persona, t.estado, t.nom_tab_anexa, t.fec_modificacion
           FROM sv_garantias t
          WHERE t.estado = 'C'
            AND EXISTS (SELECT 1
                   FROM sb_crc_garantias_det d
                  WHERE d.nro_garantia = t.nro_garantia
                    AND d.fecha <> v_fec_fin)
            AND trunc(t.fec_modificacion) BETWEEN v_fec_inicio AND v_fec_fin;
      rp_scgde       sb_crc_garantias_det%ROWTYPE;
      rp_slcrc       sb_log_crc%ROWTYPE;
      v_nro_registro sb_crc_garantias_det.nro_registro%TYPE;
   BEGIN
      pag_cal.pr_obt_dat_calendar(1);
      v_fec_actual            := pag_cal.fu_obt_fec_actual(1);
      v_fec_inicio            := pag_cal.fu_obt_fec_actual(1);
      v_fec_fin               := pag_cal.fu_obt_fec_actual(1);
      v_nro_registro          := p_nro_registro;
      rp_scgde.nom_referencia := 'GARANTIAS';
      rp_scgde.nro_formulario := '004';
      rp_scgde.fecha          := v_fec_fin;
      FOR i IN c_gar_novedades LOOP
         v_mensaje                     := NULL;
         rp_scgde.cod_oficina          := i.cod_oficina;
         rp_scgde.cod_mon_iso_garantia := i.cod_moneda;
         rp_scgde.nro_garantia         := i.nro_garantia;
         rp_scgde.cod_ref_bco_central  := i.ref_gar_bcp;
         rp_scgde.rango                := i.rango;
         rp_scgde.fec_valor            := i.fec_inicio;
         rp_scgde.fec_vencimiento      := i.fec_vencimiento;
         rp_scgde.mto_garantia         := i.valor;
         rp_scgde.mto_gar_equ_local    := i.valor;
         rp_scgde.perfeccionada        := i.perfeccionada;
         rp_scgde.cod_persona          := i.cod_persona;
         rp_scgde.tip_gar_especifica   := i.tipo;
         rp_scgde.est_garantia         := i.estado;
         lp_obt_dat_garantia_det(rp_scgde.nro_garantia,
                                 i.nom_tab_anexa,
                                 rp_scgde.mto_tas_asegurable,
                                 rp_scgde.mto_tas_no_asegurable,
                                 rp_scgde.mto_asegurado,
                                 rp_scgde.fec_ini_tasacion,
                                 rp_scgde.fec_vto_tasacion,
                                 rp_scgde.nro_inscripcion,
                                 rp_scgde.fec_ini_seguro,
                                 rp_scgde.fec_vto_seguro,
                                 rp_scgde.cod_mon_iso_seguro);
         IF i.perfeccionada = 'S' AND i.ref_gar_bcp IN (1, 2) AND rp_scgde.nro_inscripcion IS NULL THEN
            rp_scgde.nro_inscripcion := '0';
         END IF;
         --si la tasacion esta vencida tomar como fec_vto_tasacion la fecha
         --de vencimiento de la garantia
         IF rp_scgde.fec_vto_tasacion IS NULL THEN
            rp_scgde.fec_vto_tasacion := i.fec_vencimiento;
         END IF;

         rp_scgde.mto_seg_equ_local        := rp_scgde.mto_asegurado;
         rp_scgde.mto_tas_ase_equ_local    := rp_scgde.mto_tas_asegurable;
         rp_scgde.mto_tas_no_ase_equ_local := rp_scgde.mto_tas_no_asegurable;
         rp_scgde.fec_confirmacion         := i.fec_inicio;
         --- Inserta la Garantia solo si hubo un cambio en alguno de los datos
         IF lf_ver_nov_garantia(rp_scgde) = 'S' then
            IF lf_ver_nov_fec_valor(rp_scgde.fec_valor, rp_scgde.nro_garantia) = 'N' THEN
               rp_scgde.fec_valor := v_fec_fin;
            END IF;
            v_nro_registro        := v_nro_registro + 1;
            rp_scgde.nro_registro := v_nro_registro;
            lp_ins_garantias_det(rp_scgde);
            IF v_mensaje IS NOT NULL THEN
               rp_slcrc.fecha          := rp_scgde.fecha;
               rp_slcrc.nom_referencia := rp_scgde.nom_referencia;
               rp_slcrc.usu_insercion  := substr(USER, 1, 10);
               rp_slcrc.fec_insercion  := SYSDATE;
               rp_slcrc.mensaje        := 'ERROR: Garantia numero = ' || i.nro_garantia || ': ' || v_mensaje ||
                                          '; Nro. Registro: ' || rp_scgde.nro_registro;
               rp_slcrc.nro_registro   := rp_scgde.nro_registro;
               lp_log_crc(rp_slcrc);
            END IF;
         END IF;
      END LOOP;
   END;
   -- Procedimientos que contiene los datos exigidos para el archivo de Garantias
   PROCEDURE pr_crc_gen_garantias IS
      CURSOR c_garantias IS
         SELECT t.cod_oficina, t.cod_moneda, t.nro_garantia, t.cod_garantia, t.ref_gar_bcp, t.rango, t.fec_inicio,
                t.fec_confirmacion, t.fec_vencimiento, t.valor, t.cod_mon_tasacion, t.tipo, t.perfeccionada,
                t.cod_persona, t.estado, t.nom_tab_anexa
           FROM sv_garantias t
          WHERE t.estado = 'C'
            AND t.fec_confirmacion BETWEEN v_fec_inicio AND v_fec_fin
      AND NOT EXISTS (SELECT 1
                            FROM sb_crc_garantias_det d
                            WHERE d.nro_garantia = t.nro_garantia
                            AND d.fecha < v_fec_fin);

      rp_scgde sb_crc_garantias_det%ROWTYPE;
      rp_slcrc sb_log_crc%ROWTYPE;

      PROCEDURE lp_crc_gen_dat_garantias(p_tip_periodo IN VARCHAR2 DEFAULT 'D') IS
      BEGIN
         pag_cal.pr_obt_dat_calendar(1);
         v_fec_actual := pag_cal.fu_obt_fec_actual(1);
         v_fec_inicio := pag_cal.fu_obt_fec_actual(1);
         v_fec_fin    := pag_cal.fu_obt_fec_actual(1);
         IF p_tip_periodo = 'M' THEN
            v_fec_inicio := pag_cal.g_pri_dia_mes;
            v_fec_fin    := pag_cal.g_ult_dia_mes;
         END IF;
         DELETE sb_crc_garantias_det
          WHERE fecha = v_fec_fin;
         DELETE sb_crc_garantias
          WHERE fec_periodo = v_fec_fin;
         DELETE sb_log_crc
          WHERE nom_referencia = 'GARANTIAS'
            AND fecha = v_fec_fin;
         COMMIT;
         v_nro_registro := 0; --
      END;
   BEGIN
      lp_crc_gen_dat_garantias('D');

      rp_scgde.nom_referencia := 'GARANTIAS';
      rp_scgde.nro_formulario := '004';
      rp_scgde.fecha          := v_fec_fin;
      FOR i IN c_garantias LOOP
         v_mensaje := NULL;
         IF i.ref_gar_bcp IS NULL THEN
            v_mensaje := ', Referencia de Garantia BCP para el tipo: ' || i.cod_garantia || ' es nulo.';
         END IF;
         rp_scgde.cod_oficina          := i.cod_oficina;
         rp_scgde.cod_mon_iso_garantia := i.cod_moneda;
         rp_scgde.nro_garantia         := i.nro_garantia;
         rp_scgde.cod_ref_bco_central  := i.ref_gar_bcp;
         rp_scgde.rango                := i.rango;
         rp_scgde.fec_valor            := i.fec_inicio;
         rp_scgde.fec_vencimiento      := i.fec_vencimiento;
         IF rp_scgde.fec_valor > rp_scgde.fec_vencimiento THEN
            v_mensaje := v_mensaje || ', Fecha Inicio Garantia menor a la Fecha Vto. Garantia';
         END IF;
         rp_scgde.mto_garantia       := i.valor;
         rp_scgde.mto_gar_equ_local  := i.valor;
         rp_scgde.perfeccionada      := i.perfeccionada;
         rp_scgde.cod_persona        := i.cod_persona;
         rp_scgde.tip_gar_especifica := i.tipo;
         rp_scgde.est_garantia       := i.estado;
         lp_obt_dat_garantia_det(rp_scgde.nro_garantia,
                                 i.nom_tab_anexa,
                                 rp_scgde.mto_tas_asegurable,
                                 rp_scgde.mto_tas_no_asegurable,
                                 rp_scgde.mto_asegurado,
                                 rp_scgde.fec_ini_tasacion,
                                 rp_scgde.fec_vto_tasacion,
                                 rp_scgde.nro_inscripcion,
                                 rp_scgde.fec_ini_seguro,
                                 rp_scgde.fec_vto_seguro,
                                 rp_scgde.cod_mon_iso_seguro);
         IF i.perfeccionada = 'S' AND i.ref_gar_bcp IN (1, 2) AND rp_scgde.nro_inscripcion IS NULL THEN
            rp_scgde.nro_inscripcion := '0';
         END IF;
         rp_scgde.mto_seg_equ_local        := rp_scgde.mto_asegurado;
         rp_scgde.mto_tas_ase_equ_local    := rp_scgde.mto_tas_asegurable;
         rp_scgde.mto_tas_no_ase_equ_local := rp_scgde.mto_tas_no_asegurable;
         rp_scgde.fec_confirmacion         := i.fec_confirmacion;
         v_nro_registro                    := v_nro_registro + 1;
         rp_scgde.nro_registro             := v_nro_registro;
         --- Inserta GARANTIAS
         lp_ins_garantias_det(rp_scgde);
         -- Inserta Log
         IF v_mensaje IS NOT NULL THEN
            rp_slcrc.fecha          := rp_scgde.fecha;
            rp_slcrc.nom_referencia := rp_scgde.nom_referencia;
            rp_slcrc.usu_insercion  := substr(USER, 1, 10);
            rp_slcrc.fec_insercion  := SYSDATE;
            rp_slcrc.mensaje        := 'ERROR: Garantia numero = ' || i.nro_garantia || ': ' || v_mensaje ||
                                       '; Nro. Registro: ' || rp_scgde.nro_registro;
            rp_slcrc.nro_registro   := rp_scgde.nro_registro;
            lp_log_crc(rp_slcrc);
         END IF;
      END LOOP;
      -- Ejecutar las novedades luego del ciclo de garantias
      pr_crc_gen_gar_novedades(v_nro_registro);
      lp_act_tot_registro(v_fec_fin, 'SB_CRC_GARANTIAS'); --- totalizar los registros
   END;
   FUNCTION fu_obt_cod_tra_computable(p_cod_garantia pr_gar_tipos.cod_garantia%type) RETURN NUMBER IS
      v_cod_tra_computable pr_gar_tipos.cod_transaccion1%TYPE;
   BEGIN
      SELECT cod_transaccion1
        INTO v_cod_tra_computable
        FROM pr_gar_tipos
       WHERE cod_garantia = p_cod_garantia;
      RETURN v_cod_tra_computable;
   EXCEPTION
      WHEN OTHERS THEN
         RETURN NULL;
   END;

   PROCEDURE pr_ins_cta_gar_eliminadas(rp_scgel IN sb_cta_gar_eliminadas%ROWTYPE) IS
   BEGIN
      -- Se agrega para eliminar el registro en caso de que ya se haya insertado en la fecha de modo a
      -- tener solo la ultima modificacion o eliminacion de la garantia de la fecha  -- CN DYDMR-1020 --
      DELETE sb_cta_gar_eliminadas
       WHERE fecha = rp_scgel.fecha
         AND nro_garantia = rp_scgel.nro_garantia
         AND nro_cuenta = rp_scgel.nro_cuenta;
      --
      INSERT INTO sb_cta_gar_eliminadas
         (fecha, hora, nro_garantia, nro_cuenta, cod_persona, cod_garantia, mto_apl_computable)
      VALUES
         (rp_scgel.fecha, rp_scgel.hora, rp_scgel.nro_garantia, rp_scgel.nro_cuenta, rp_scgel.cod_persona, rp_scgel.cod_garantia,
          rp_scgel.mto_apl_computable);
   EXCEPTION
          WHEN OTHERS THEN
             raise_application_error(-20003, 'Error al actualizar la Garant?a: '||''||rp_scgel.nro_garantia);
   END;

   PROCEDURE pr_ins_cta_garantias_nov(rp_scgel IN sb_cta_garantias_nov%ROWTYPE) IS
   BEGIN

      INSERT INTO sb_cta_garantias_nov
         (fecha, hora, nro_garantia, nro_cuenta, cod_persona, cod_garantia, mto_apl_computable)
      VALUES
         (rp_scgel.fecha,
          rp_scgel.hora,
          rp_scgel.nro_garantia,
          rp_scgel.nro_cuenta,
          rp_scgel.cod_persona,
          rp_scgel.cod_garantia,
          rp_scgel.mto_apl_computable);
   END;
   -- Procedimiento de insercion de Garantias
   PROCEDURE lp_ins_ope_garantias_det(rp_scogd sb_crc_ope_garantias_det%ROWTYPE) IS
      v_cotizacion ge_cotizaciones.val_conversion%TYPE;
   BEGIN
      IF rp_scogd.cod_mon_iso_operacion <> v_cod_mon_local THEN
         v_cotizacion := nvl(fug_obt_cotizacion(rp_scogd.cod_mon_iso_operacion, rp_scogd.fecha), 1);
      ELSE
         v_cotizacion := 1;
      END IF;

      INSERT INTO sb_crc_ope_garantias_det
         (fecha,
          nom_referencia,
          nro_registro,
          nro_formulario,
          cod_ofi_operacion,
          tip_operacion,
          nro_operacion,
          cod_mon_iso_operacion,
          cod_ofi_garantia,
          cod_mon_iso_garantia,
          nro_garantia,
          cod_ref_bco_central,
          rub_con_garantia,
          mto_utilizado,
          mto_equ_utilizado,
          tip_gar_especifica,
          cod_modulo,
          cod_modalidad,
          cod_persona)
      VALUES
         (rp_scogd.fecha,
          rp_scogd.nom_referencia,
          rp_scogd.nro_registro,
          rp_scogd.nro_formulario,
          rp_scogd.cod_ofi_operacion,
          rp_scogd.tip_operacion,
          rp_scogd.nro_operacion,
          rp_scogd.cod_mon_iso_operacion,
          rp_scogd.cod_ofi_garantia,
          rp_scogd.cod_mon_iso_garantia,
          rp_scogd.nro_garantia,
          rp_scogd.cod_ref_bco_central,
          rp_scogd.rub_con_garantia,
          rp_scogd.mto_utilizado,
          round(rp_scogd.mto_equ_utilizado * v_cotizacion, v_redondeo),
          rp_scogd.tip_gar_especifica,
          rp_scogd.cod_modulo,
          rp_scogd.cod_modalidad,
          rp_scogd.cod_persona);
   END;
   PROCEDURE pr_crc_ope_gar_eli IS
      CURSOR c_ope_gar_eli IS
         SELECT fecha, nro_operacion, cod_ofi_operacion, cod_mon_iso_operacion, cod_persona, tip_operacion, cod_modulo,
                cod_modalidad, nro_garantia, cod_ofi_garantia, cod_mon_iso_garantia, cod_ref_bco_central,
                tip_gar_especifica, cod_garantia, mto_apl_computable
           FROM sv_cta_garantias_nov
          WHERE trunc(fecha) BETWEEN v_fec_inicio AND v_fec_fin;

      rp_scogd             sb_crc_ope_garantias_det%ROWTYPE;
      v_cod_tra_computable pr_gar_tipos.cod_transaccion1%TYPE;
   BEGIN
      v_nro_registro          := 0;
      rp_scogd.nom_referencia := 'OPEGARELI';
      rp_scogd.nro_formulario := '010';
      rp_scogd.fecha          := v_fec_fin;
      FOR i IN c_ope_gar_eli LOOP
         rp_scogd.cod_ofi_operacion     := i.cod_ofi_operacion;
         rp_scogd.tip_operacion         := i.tip_operacion;
         rp_scogd.nro_operacion         := i.nro_operacion;
         rp_scogd.cod_mon_iso_operacion := i.cod_mon_iso_operacion;
         rp_scogd.cod_ofi_garantia      := i.cod_ofi_garantia;
         rp_scogd.cod_mon_iso_garantia  := i.cod_mon_iso_garantia;
         rp_scogd.nro_garantia          := i.nro_garantia;
         rp_scogd.cod_ref_bco_central   := i.cod_ref_bco_central;
         v_cod_tra_computable           := fu_obt_cod_tra_computable(i.cod_garantia);
         rp_scogd.rub_con_garantia      := IT.pas_cri.fu_obt_cod_rubro(pae_uti.fu_obt_valor(i.nro_operacion,1),null,null, v_cod_tra_computable, null,null,null,null,null, 'C',null,null,null,null,null,null,null);
         rp_scogd.mto_utilizado         := i.mto_apl_computable;
         rp_scogd.mto_equ_utilizado     := i.mto_apl_computable;
         rp_scogd.tip_gar_especifica    := i.tip_gar_especifica;
         rp_scogd.cod_modulo            := i.cod_modulo;
         rp_scogd.cod_modalidad         := i.cod_modalidad;
         rp_scogd.cod_persona           := i.cod_persona;
         v_nro_registro                 := v_nro_registro + 1;
         rp_scogd.nro_registro          := v_nro_registro;
         --- Inserta GARANTIAS
         lp_ins_ope_garantias_det(rp_scogd);
      END LOOP;
      lp_act_tot_registro(v_fec_fin, 'SB_CRC_OPE_GARANTIAS', 'OPEGARELI'); --- totalizar los registros
   END;

   PROCEDURE pr_crc_ope_gar IS
      CURSOR c_ope_gar IS
         SELECT distinct fecha, nro_operacion, cod_ofi_operacion, cod_mon_iso_operacion, cod_modulo, cod_modalidad,
                         cod_persona, tip_operacion, nro_garantia, cod_ofi_garantia, cod_mon_iso_garantia,
                         cod_ref_bco_central, tip_gar_especifica, cod_garantia, mto_aplicado, fec_insercion
           FROM sv_ope_garantias a
          WHERE to_date(to_char(a.fec_insercion, 'dd/mm/yyyy'), 'dd/mm/yyyy') BETWEEN v_fec_inicio AND v_fec_fin
            AND NOT EXISTS (SELECT 1
                   FROM sb_crc_ope_garantias_det r
                  WHERE r.nro_operacion = a.nro_operacion
                    AND r.nro_garantia = a.nro_garantia);

      rp_scogd             sb_crc_ope_garantias_det%ROWTYPE;
      v_cod_tra_computable pr_gar_tipos.cod_transaccion1%TYPE;

      PROCEDURE lp_crc_gen_dat_ope_gar IS
      BEGIN
         pag_cal.pr_obt_dat_calendar(1);
         v_fec_actual := pag_cal.fu_obt_fec_actual(1);
         v_fec_inicio := pag_cal.fu_obt_fec_actual(1);
         v_fec_fin    := pag_cal.fu_obt_fec_actual(1);
         DELETE sb_crc_ope_garantias_det
          WHERE fecha = v_fec_fin;
         DELETE sb_crc_ope_garantias
          WHERE fec_periodo = v_fec_fin;
         COMMIT;
         v_nro_registro := 0;
      END;
   BEGIN
      lp_crc_gen_dat_ope_gar;

      rp_scogd.nom_referencia := 'OPEGARAN';
      rp_scogd.nro_formulario := '010';
      rp_scogd.fecha          := v_fec_fin;
      FOR i IN c_ope_gar LOOP
         rp_scogd.cod_ofi_operacion     := i.cod_ofi_operacion;
         rp_scogd.tip_operacion         := i.tip_operacion;
         rp_scogd.nro_operacion         := i.nro_operacion;
         rp_scogd.cod_mon_iso_operacion := i.cod_mon_iso_operacion;
         rp_scogd.cod_ofi_garantia      := i.cod_ofi_garantia;
         rp_scogd.cod_mon_iso_garantia  := i.cod_mon_iso_garantia;
         rp_scogd.nro_garantia          := i.nro_garantia;
         rp_scogd.cod_ref_bco_central   := i.cod_ref_bco_central;
         v_cod_tra_computable           := fu_obt_cod_tra_computable(i.cod_garantia);
         rp_scogd.rub_con_garantia      := IT.pas_cri.fu_obt_cod_rubro(pae_uti.fu_obt_valor(i.nro_operacion,1),null,null, v_cod_tra_computable, null,null,null,null,null,'C',null,null,null,null,null,null,null);
         rp_scogd.mto_utilizado         := i.mto_aplicado;
         rp_scogd.mto_equ_utilizado     := i.mto_aplicado;
         rp_scogd.tip_gar_especifica    := i.tip_gar_especifica;
         rp_scogd.cod_modulo            := i.cod_modulo;
         rp_scogd.cod_modalidad         := i.cod_modalidad;
         rp_scogd.cod_persona           := i.cod_persona;
         v_nro_registro                 := v_nro_registro + 1;
         rp_scogd.nro_registro          := v_nro_registro;
         --- Inserta GARANTIAS
         lp_ins_ope_garantias_det(rp_scogd);
      END LOOP;
      pr_crc_ope_gar_eli;
      lp_act_tot_registro(v_fec_fin, 'SB_CRC_OPE_GARANTIAS', 'OPEGARAN'); --- totalizar los registros
   END;
   PROCEDURE pr_ins_crc_ope_no_enviados(rp_gcope sb_crc_operaciones_det%ROWTYPE) IS
   BEGIN
      INSERT INTO sb_crc_ope_no_enviados
         (fecha,
          nom_referencia,
          nro_formulario,
          cod_oficina,
          tip_operacion,
          nro_operacion,
          cod_moneda,
          fec_operacion,
          fec_pri_vencimiento,
          nro_cuota,
          cta_con_cap_original,
          mto_ori_capital,
          mto_lin_credito,
          cta_con_int_original,
          mto_ori_interes,
          cod_rub_primario,
          cod_departamento,
          cod_rub_economico,
          dia_plazo,
          tas_nominal,
          nro_registro)
      VALUES
         (rp_gcope.fecha,
          rp_gcope.nom_referencia,
          rp_gcope.nro_formulario,
          nvl(fug_obt_pardinamico('COD_OFI_NO_HAB_BCP', NULL, NULL, NULL, rp_gcope.cod_oficina), rp_gcope.cod_oficina),
          rp_gcope.tip_operacion,
          rp_gcope.nro_operacion,
          rp_gcope.cod_moneda,
          rp_gcope.fec_operacion,
          rp_gcope.fec_pri_vencimiento,
          rp_gcope.nro_cuota,
          rp_gcope.cta_con_cap_original,
          rp_gcope.mto_ori_capital,
          rp_gcope.mto_lin_credito,
          rp_gcope.cta_con_int_original,
          rp_gcope.mto_ori_interes,
          rp_gcope.cod_rub_primario,
          rp_gcope.cod_departamento,
          rp_gcope.cod_rub_economico,
          rp_gcope.dia_plazo,
          rp_gcope.tas_nominal,
          rp_gcope.nro_registro);
   END;
   PROCEDURE lp_crc_ins_act_vinculos(rp_scavd sb_crc_act_vinculos_det%ROWTYPE) IS
   BEGIN
      -- inserto los datos en sb_crc_act_vinculos_det
      INSERT INTO sb_crc_act_vinculos_det
         (fecha,
          nom_referencia,
          nro_formulario,
          cod_oficina,
          tip_operacion,
          nro_operacion,
          cod_mon_iso,
          tip_documento,
          nro_documento,
          evento,
          nro_registro,
          cod_persona,
          cod_modulo)
      VALUES
         (rp_scavd.fecha,
          rp_scavd.nom_referencia,
          rp_scavd.nro_formulario,
          nvl(fug_obt_pardinamico('COD_OFI_NO_HAB_BCP', NULL, NULL, NULL, rp_scavd.cod_oficina), rp_scavd.cod_oficina),
          rp_scavd.tip_operacion,
          rp_scavd.nro_operacion,
          rp_scavd.cod_mon_iso,
          rp_scavd.tip_documento,
          rp_scavd.nro_documento,
          rp_scavd.evento,
          rp_scavd.nro_registro,
          rp_scavd.cod_persona,
          rp_scavd.cod_modulo);
   END;

   PROCEDURE pr_crc_gen_act_vin IS
      CURSOR c_vinculos IS
         SELECT DISTINCT fecha, nro_cuenta,nro_cheque, cod_oficina, cod_moneda, cod_persona, tip_operacion, cod_modulo, estado,
                         cod_modalidad, decode(nvl(evento, 'V'), 'D', 'S', 'N') evento, 'N' vta_cartera
           FROM sv_cta_vinculos_nov a
          WHERE to_date(to_char(a.fecha, 'dd/mm/yyyy'), 'dd/mm/yyyy') BETWEEN v_fec_inicio AND v_fec_fin
          and exists (select 1 from sb_crc_operaciones_det o where o.nro_operacion = a.nro_cuenta and o.tip_operacion = a.tip_operacion)--FIELDESK-13627 ajuste por cuentas incorrectas de migracion
         /* union
          SELECT DISTINCT s.fec_ope_ente, s.nro_cuenta,null,i.cod_oficina \*s.cod_oficina*\, s.cod_moneda, b.cod_persona, i.tip_operacion, i.cod_modulo, 'C' ,
                         cod_modalidad, 'N', 'S' vta_cartera --fieldesk-13627 --se mantiene oficina original de la operacion
            FROM ge_cta_dat_adicionales a, ge_entes b, pr_vta_carteras s, sb_crc_operaciones_det i
           WHERE parametro = 'ENT_ADM_CARTERA'
             AND b.descripcion = a.val_parametro
             AND b.tipo = 'AC'
             AND s.fec_ope_ente BETWEEN v_fec_inicio AND v_fec_fin
             and pae_uti.fu_obt_valor(i.nro_operacion, 1)  = s.nro_cuenta--pae_uti.fu_obt_valor(fus_obt_cta_operacion(i.nro_operacion,i.cod_modulo), 1)  = s.nro_cuenta
             AND a.nro_cuenta = s.nro_cuenta--AND a.nro_cuenta = pae_uti.fu_obt_valor(s.nro_cuenta, 1);
            */ ;
      CURSOR c_ope_vinculos IS
         SELECT DISTINCT gcta.nro_cuenta
           FROM ge_cuentas gcta, ge_cta_clientes gctacl, ge_est_cuentas gest
          WHERE gcta.nro_cuenta = gctacl.nro_cuenta
            and relacion = 'P'
            and gcta.cod_modulo = gest.cod_modulo
            and gcta.cod_modalidad = gest.cod_modalidad
            and gcta.estado = gest.estado
            and gest.activo = 'S'
            and cod_persona = v_vin_cod_persona;

      rg_scavd               sb_crc_act_vinculos_det%ROWTYPE;
      v_fec_nacimiento       sb_crc_vinculos_det.fec_nacimiento%TYPE;
      v_nombres              sb_crc_vinculos_det.nombres%TYPE;
      v_apellidos            sb_crc_vinculos_det.apellidos%TYPE;
      v_informar             VARCHAR2(1) := 'S';
      v_inf_vinculo          VARCHAR2(1) := 'N';
      v_cta_con_cap_original sb_crc_operaciones_det.cta_con_cap_original%TYPE;

      PROCEDURE lp_crc_gen_dat_act_vin IS
      BEGIN
         pag_cal.pr_obt_dat_calendar(1);
         v_fec_actual := pag_cal.fu_obt_fec_actual(1);
         v_fec_inicio := pag_cal.fu_obt_fec_actual(1);
         v_fec_fin    := pag_cal.fu_obt_fec_actual(1);
         DELETE sb_crc_act_vinculos_det
          WHERE fecha = v_fec_fin;
         DELETE sb_crc_act_vinculos
          WHERE fec_periodo = v_fec_fin;
         COMMIT;
         v_nro_registro := 0;
      END;
      FUNCTION lf_ver_cta_duplicada(p_nro_cuenta  ge_cuentas.nro_cuenta%TYPE,
                                    p_cod_persona ge_cta_clientes.cod_persona%TYPE) RETURN VARCHAR2 IS
         v_desvinculacion VARCHAR2(1);
         v_vinculacion    VARCHAR2(1);
         v_evento         VARCHAR2(1);
      BEGIN
         SELECT SUM(nvl(decode(evento, 'D', COUNT(*)), 0)), SUM(nvl(decode(evento, 'V', COUNT(*)), 0))
           INTO v_desvinculacion, v_vinculacion
           FROM sb_cta_vinculos_nov t
          WHERE (nro_cuenta = p_nro_cuenta OR NRO_CUENTA IS NULL)
            AND cod_persona = p_cod_persona
            AND to_date(to_char(fecha, 'dd/mm/yyyy'), 'dd/mm/yyyy') BETWEEN v_fec_inicio AND v_fec_fin
          GROUP BY evento;

         IF v_desvinculacion = v_vinculacion THEN
            -- no informar
            v_evento := NULL;
         ELSIF v_desvinculacion > v_vinculacion THEN
            -- informar desvinculacion
            v_evento := 'S';
         ELSIF v_desvinculacion < v_vinculacion THEN
            -- informar vinculacion
            v_evento := 'N';
         END IF;
         RETURN v_evento;
      EXCEPTION
         WHEN no_data_found THEN
            RETURN NULL;
         WHEN OTHERS THEN
            RETURN NULL;
      END;

      FUNCTION lf_ver_cta_informada(p_nro_cuenta  ge_cuentas.nro_cuenta%TYPE,
                                    p_cod_persona ge_cta_clientes.cod_persona%TYPE) RETURN VARCHAR2 IS
         v_existe VARCHAR2(1) := 'N';
      BEGIN
         SELECT DISTINCT 'S'
           INTO v_existe
           FROM sb_crc_vinculos_det
          WHERE cod_persona = p_cod_persona
            AND nro_operacion = p_nro_cuenta;
         RETURN v_existe;
      EXCEPTION
         WHEN no_data_found THEN
            RETURN 'N';
         WHEN OTHERS THEN
            RETURN 'N';
      END;

      FUNCTION lf_ver_cta_desvinculada(p_nro_cuenta  ge_cuentas.nro_cuenta%TYPE,
                                       p_cod_persona ge_cta_clientes.cod_persona%TYPE) RETURN VARCHAR2 IS
         v_existe VARCHAR2(1) := 'N';
      BEGIN
         SELECT DISTINCT 'S'
           INTO v_existe
           FROM sb_crc_vinculos_det
          WHERE cod_persona = p_cod_persona
            AND nro_operacion = p_nro_cuenta;
         RETURN v_existe;
      EXCEPTION
         WHEN no_data_found THEN
            RETURN 'N';
         WHEN OTHERS THEN
            RETURN 'N';
      END;

      FUNCTION lf_ver_desvinculacion( -- verifica que la desvinculacion sea real, ya que puede haberse grabado como desvinculacion pero no corresponde.
                                     p_nro_cuenta  ge_cuentas.nro_cuenta%TYPE,
                                     p_cod_persona ge_cta_clientes.cod_persona%TYPE) RETURN VARCHAR2 IS
         v_existe   VARCHAR2(1) := 'S';
         v_relacion ge_cta_clientes.relacion%type;
      BEGIN
         SELECT relacion
           INTO v_relacion
           FROM sb_cta_vinculos_nov
          WHERE to_date(to_char(fecha, 'dd/mm/yyyy'), 'dd/mm/yyyy') = v_fec_fin
            AND cod_persona = p_cod_persona
            AND (nro_cuenta = p_nro_cuenta OR nro_cuenta IS NULL);
         IF v_relacion = 'E' THEN
            SELECT DISTINCT 'N'
              INTO v_existe
              FROM ba_vinculos
             WHERE cod_persona = p_cod_persona
               AND tipo = 'E';
         ELSIF v_relacion <> 'L' THEN
            SELECT DISTINCT 'N'
              INTO v_existe
              FROM ge_cta_clientes
             WHERE cod_persona = p_cod_persona
               AND nro_cuenta = p_nro_cuenta;
         END IF;
         RETURN v_existe;
      EXCEPTION
         WHEN no_data_found THEN
            RETURN 'S';
         WHEN too_many_rows THEN
            RETURN 'S';
         WHEN OTHERS THEN
            RETURN 'S';
      END;
      FUNCTION lf_obt_cta_con_cap_original(p_nro_operacion sb_crc_operaciones_det.nro_operacion%TYPE,
                                           p_tip_operacion sb_crc_operaciones_det.tip_operacion%TYPE) RETURN VARCHAR2 IS
         v_cta sb_crc_operaciones_det.cta_con_cap_original%TYPE;
         v_nro_cuenta ge_cta_clientes.nro_cuenta%TYPE := NVL(lf_obt_cta_isin(p_nro_operacion), p_nro_operacion);
      BEGIN
         SELECT distinct (cta_con_cap_original)
           INTO v_cta
           FROM sb_crc_operaciones_det a, ge_cta_clientes b
          WHERE a.cod_persona = b.cod_persona
            AND b.nro_cuenta = v_nro_cuenta
            AND nro_operacion = p_nro_operacion
            AND tip_operacion = p_tip_operacion
            AND b.relacion = 'P';
         RETURN v_cta;
      EXCEPTION
         WHEN no_data_found THEN
            RETURN null;
      END;
function lf_obt_tip_entidad(p_cod_persona ba_personas.cod_persona%type) return varchar2 is
      v_entidad varchar2(1) := 'N';
   begin
      select distinct 'S'
        into v_entidad
        from ge_entes
       where tipo = 'FI'
         and cod_persona = p_cod_persona
      union all
      select distinct 'S'
        from ge_bancos
       where cod_persona = p_cod_persona;

      return v_entidad;
   exception
      when no_data_found then
         return 'N';
      when too_many_rows then
         return 'S';
      when others then
         return 'N';
   end;
   BEGIN
      lp_crc_gen_dat_act_vin;
      rg_scavd.nom_referencia := 'VINCULOSD';
      rg_scavd.nro_formulario := '005';
      rg_scavd.fecha          := v_fec_fin;
      FOR i IN c_vinculos LOOP
         v_informar             := 'S';
         v_inf_vinculo          := 'N';
         rg_scavd.cod_oficina   := i.cod_oficina;
         rg_scavd.tip_operacion := i.tip_operacion;
         rg_scavd.nro_operacion := i.nro_cuenta;
         rg_scavd.cod_mon_iso   := fu_obt_mon_iso(i.cod_moneda);
         lp_obt_dat_persona(i.cod_persona,
                            rg_scavd.tip_documento,
                            rg_scavd.nro_documento,
                            v_fec_nacimiento,
                            v_nombres,
                            v_apellidos);
         rg_scavd.evento      := i.evento;
         rg_scavd.cod_modulo  := i.cod_modulo;
         rg_scavd.cod_persona := i.cod_persona;

         -- Si se vinculo un nuevo codigo de persona pero es el mismo documento informado, no enviar como actualizacion
         IF i.evento = 'N' AND rg_scavd.tip_documento IS NOT NULL AND rg_scavd.nro_documento IS NOT NULL THEN
            BEGIN
              if i.vta_cartera <> 'S' then
               SELECT DISTINCT 'S'
                 INTO v_informar
                 FROM sb_crc_vinculos_det
                WHERE nro_documento = rg_scavd.nro_documento
                  AND tip_documento = rg_scavd.tip_documento
                  and tip_operacion = rg_scavd.tip_operacion--fieldesk-5268--para permitir vinculacion de cuentas CDA
                  AND pae_uti.fu_obt_valor(fus_obt_cta_operacion(nro_operacion,cod_modulo), 1) = i.nro_cuenta;
               else
                   select distinct 'S'
                   into v_informar
                   from sb_crc_vinculos_det
                  where nro_documento = rg_scavd.nro_documento
                    and tip_documento = rg_scavd.tip_documento
                    and tip_operacion = rg_scavd.tip_operacion--fieldesk-5268--para permitir vinculacion de cuentas cda
                    and tip_vinculo  in (9)
                    and pae_uti.fu_obt_valor(fus_obt_cta_operacion(nro_operacion,cod_modulo), 1) = i.nro_cuenta;
               end if;
            EXCEPTION
               WHEN no_data_found THEN
                  v_inf_vinculo := 'S';
               WHEN too_many_rows THEN
                  v_informar := 'N';
               WHEN OTHERS THEN
                  v_informar := 'S';
            END;
         END IF;

         -- Si la cuenta y persona ya fueron informadas en vinculos y el evento es vinculacion: no informar.
/*         IF lf_ver_cta_informada(pae_uti.fu_obt_valor(fus_obt_cta_operacion(i.nro_cuenta,i.cod_modulo), 1), i.cod_persona) = 'S' AND i.evento = 'N' THEN
            v_informar := 'N';
         END IF;*/
         -- Si esta la persona como vinculado y desvinculado de la misma cuenta no debe informarse.
/*         IF lf_ver_cta_duplicada(i.nro_cuenta, i.cod_persona) IS NULL THEN
            v_informar := 'N';
         ELSIF lf_ver_cta_duplicada(i.nro_cuenta, i.cod_persona) = 'S' THEN
            rg_scavd.evento := 'S';
         ELSIF lf_ver_cta_duplicada(i.nro_cuenta, i.cod_persona) = 'N' THEN
            rg_scavd.evento := 'N';
         END IF;
         -- Vuelve a verificar si la desvinculacion guardada por el trigger es realmente una desvinculacion de la persona
         IF lf_ver_desvinculacion(i.nro_cuenta, i.cod_persona) = 'N' AND i.evento = 'S' THEN
            v_informar := 'N';
         END IF;*/

        /* IF i.cod_modulo IN (6, 10) AND i.estado = 'N' THEN
            v_informar := 'N';
         ELS*/
         IF i.cod_modulo IN (4, 5, 3, 8, 15) AND i.estado = 'C' THEN
            v_informar := 'N';
         ELSIF i.cod_modalidad IN (33, 34) AND i.estado = 'T' THEN
            v_informar := 'N';
         END IF;
         if lf_obt_tip_entidad(i.cod_persona)= 'S' then --agregado para que no genere los vinculos de las ventas a entes financieros 28/04/2023 pendiente al pase
             v_informar := 'N';
        end if;
         --- Inserta act. vinculos
         -- El codigo de persona fue eliminado o unificado con otro codigo.
         IF rg_scavd.tip_documento IS NOT NULL AND rg_scavd.nro_documento IS NOT NULL AND v_informar = 'S' AND
            nvl(v_inf_vinculo, 'N') = 'N' THEN
            v_nro_registro        := v_nro_registro + 1;
            rg_scavd.nro_registro := v_nro_registro;
            lp_crc_ins_act_vinculos(rg_scavd);
         END IF;
         IF rg_scavd.tip_documento IS NOT NULL AND rg_scavd.nro_documento IS NOT NULL AND nvl(v_inf_vinculo, 'N') = 'S' THEN
            v_cta_con_cap_original := lf_obt_cta_con_cap_original(rg_scavd.nro_operacion, rg_scavd.tip_operacion);
            v_nro_reg_vin          := fu_obt_reg_vinculo(v_fec_fin, 'VINCULOS');
            IF rg_scavd.nro_operacion is null THEN
               v_vin_cod_persona := rg_scavd.cod_persona;
               FOR x IN c_ope_vinculos LOOP
                  rg_scavd.nro_operacion := x.nro_cuenta;
                  lp_crc_gen_vinculos(rg_scavd.cod_oficina,
                                      rg_scavd.nro_operacion,
                                      1,
                                      rg_scavd.tip_operacion,
                                      v_cta_con_cap_original,
                                      rg_scavd.cod_mon_iso,
                                      rg_scavd.cod_persona);
               END LOOP;
            ELSE
               lp_crc_gen_vinculos(rg_scavd.cod_oficina,
                                   rg_scavd.nro_operacion,
                                   rg_scavd.tip_operacion,
                                   1,
                                   v_cta_con_cap_original,
                                   rg_scavd.cod_mon_iso,
                                   rg_scavd.cod_persona);
               lp_act_tot_registro(v_fec_fin, 'SB_CRC_VINCULOS');
            END IF;
         END IF;
      END LOOP;
      lp_act_tot_registro(v_fec_fin, 'SB_CRC_ACT_VINCULOS', 'VINCULOSD'); --- totalizar los registro
   END;
   ----validaci?n de datos
PROCEDURE pr_crc_val_datos IS

      CURSOR c_datos IS
        -- NOR-764 CDA-D: cuenta interna de las operaciones informadas con ISIN
        WITH hc AS (SELECT x.cod_isin, x.nro_cuenta
                      FROM (SELECT h.cod_isin, h.nro_cuenta,
                                   ROW_NUMBER() OVER (PARTITION BY h.cod_isin
                                                      ORDER BY CASE WHEN h.estado IN ('A', 'X') THEN 1 ELSE 0 END,
                                                               h.fec_apertura DESC, h.nro_cuenta DESC) rn
                              FROM ah_cta_certificados h
                             WHERE h.cod_modalidad = 34
                               AND h.cod_isin IS NOT NULL) x
                     WHERE x.rn = 1)
        /*Operaciones registradas contablemente (Cta Capital) como operaciones vigentes del
        Sector Financiero con Actividad Origen del Sector No Financiero.*/
        select d.nro_operacion,b.cod_persona,d.tip_operacion ,'Cliente sec Financiero informado con Act origen No Financiero' observacion, d.nro_registro
        from sb_crc_operaciones_det d left join hc on hc.cod_isin = d.nro_operacion, ba_personas b, ge_clientes c, ge_cta_clientes t
        where b.cod_persona=c.cod_persona
        and c.cod_sec_contable='F'
        and t.cod_persona=c.cod_persona
        and b.cod_persona=t.cod_persona
        and t.relacion='P'
        and nvl(hc.nro_cuenta, fu_obt_operacion(d.nro_operacion, 1))=t.nro_cuenta
        and b.cod_rub_primario not in(select p.val_minimo from ba_cod_referencias p where p.dominio='ACT_ECONOMICA' and p.val_maximo ='F')
        and d.fecha =v_fec_fin
        /*Operaciones registradas contablemente (Cta Capital) como operaciones vigentes del Sector Publico con Actividad Origen del Sector
         No Publico .*/
        union all
        select d.nro_operacion,b.cod_persona,d.tip_operacion ,'Cliente sec Publico informado con Act origen No Publico',d.nro_registro
        from sb_crc_operaciones_det d left join hc on hc.cod_isin = d.nro_operacion, ba_personas b, ge_clientes c, ge_cta_clientes t
        where b.cod_persona=c.cod_persona
        and c.cod_sec_contable='P'
        and t.cod_persona=c.cod_persona
        and b.cod_persona=t.cod_persona
        and t.relacion='P'
        and nvl(hc.nro_cuenta, fu_obt_operacion(d.nro_operacion, 1))=t.nro_cuenta
        and b.cod_rub_primario not in(select p.val_minimo from ba_cod_referencias p where p.dominio='ACT_ECONOMICA' and p.val_maximo ='P')
        and d.fecha =v_fec_fin
        /*Tipo de Operaciones 136-138-142 que registren Plazo d?as mayor a 0.*/
        union all
        select d.nro_operacion,d.cod_persona,d.tip_operacion ,'Tipo de Operaciones 136-138-142 con Plazo d?as mayor a 0',d.nro_registro
        from sb_crc_operaciones_det d
        where d.tip_operacion in(136,138,142)
        and d.dia_plazo>0
        and d.fecha =v_fec_fin

        /*Operaciones con Tipo de operaci?n 205 y  registradas con Actividad Destino distinto a 970107.*/
        union all
        select d.nro_operacion,d.cod_persona,d.tip_operacion ,'Operaciones con Tipo de operaci?n 205 con Actividad Destino distinto a 970107',d.nro_registro
        from sb_crc_operaciones_det d
        where d.tip_operacion in(205)
        and d.cod_rub_economico<>'970107'
        and d.fecha =v_fec_fin
        /*Operaciones crediticias (distintas a Creditos Util en Cta Cte y Deudores por utilizacion de tarjetas de creditos )
        y de ahorro a plazo fijo que presenta el campo  Plazo D?as vac?o.*/
        union all
        select d.nro_operacion,d.cod_persona,d.tip_operacion ,'Operaciones crediticias y ahorro plazo fijo Plazo Dias vacio',d.nro_registro
        from sb_crc_operaciones_det d left join hc on hc.cod_isin = d.nro_operacion, ge_cuentas g
        where (substr(d.cta_con_cap_original,1,1) ='1' or (substr(d.cta_con_cap_original,1,1)='2' and g.cod_modalidad IN (33, 34)) and d.tip_operacion<>138)---vencidos 138
        and g.nro_cuenta=nvl(hc.nro_cuenta, d.nro_operacion)
        and nvl(d.dia_plazo,0)=0
        and nvl(d.mto_ori_capital,0)<>0
        and d.fecha =v_fec_fin
        /*Operaciones crediticias (distintas a Creditos Util en Cta Cte y Deudores por utilizacion de tarjetas de creditos )
         que presentan el campo  Cuotas pactadas vac?o.*/
        union all
        select d.nro_operacion,d.cod_persona,d.tip_operacion ,'Operaciones crediticias Cuotas vacio',d.nro_registro
        from sb_crc_operaciones_det d, ge_cuentas g
        where substr(d.cta_con_cap_original,1,1) ='1'
        and g.nro_cuenta=d.nro_operacion
        and nvl(d.mto_ori_capital,0)<>0
        and nvl(d.nro_cuota,0)=0
        and d.fecha =v_fec_fin
        /*Operaciones crediticias (distintas a Creditos Util en Cta Cte y Deudores por utilizacion de tarjetas de creditos )
         y de ahorro a plazo fijo que presenta el campo  Tasa Nominal  vac?o. */
        union all
        select d.nro_operacion,d.cod_persona,d.tip_operacion ,'Operaciones crediticias y de ahorro a plazo fijo Tasa Nominal vacio',d.nro_registro
        from sb_crc_operaciones_det d left join hc on hc.cod_isin = d.nro_operacion, ge_cuentas g
        where (substr(d.cta_con_cap_original,1,1) ='1' or (substr(d.cta_con_cap_original,1,1)='2' and g.cod_modalidad IN (33, 34)))
        and g.nro_cuenta=nvl(hc.nro_cuenta, d.nro_operacion)
        and nvl(d.tas_nominal,0)=0
        and d.fecha =v_fec_fin

        /*Operaciones registradas contablemente (Cta Capital) como Primera Vivienda registradas  con
        Actividad destino distintos a  vivienda  (970000 a 970003).*/
        union all
        select t.nro_operacion,t.cod_persona,t.tip_operacion ,'Operaciones registradas (Cta Capital) como 1raVivienda con
        Actividad destino distintos a  vivienda  (970000 a 970003)' ,t.nro_registro
        from SB_CRC_OPERACIONES_DET t
        where IT.pas_cri.fu_obt_cod_bcp (t.cod_rub_economico) in('970000','970001','970002','970003')
        and substr(t.cta_con_cap_original,11,3) not in
        (select p.cod_sec_rubro from pr_rub_economicos p
        where IT.pas_cri.fu_obt_cod_bcp (p.cod_rub_economico) in('970000','970001','970002','970003'))
        and t.fecha =v_fec_fin
        /*Operaciones con Plazo D?as mayor a 36500  (10 a?os) - excluye Actividades Destino que  sean relacionados a vivienda
        (970000 a 970003).*/
        union all
        select t.nro_operacion,t.cod_persona,t.tip_operacion ,'Operaciones con Plazo D?as> 36500-excluye Actividades Destino que sean relacionados a vivienda
        (970000 a 970003)' ,t.nro_registro
        from SB_CRC_OPERACIONES_DET t
        where IT.pas_cri.fu_obt_cod_bcp (t.cod_rub_economico) not in('970000','970001','970002','970003')
        and nvl(t.dia_plazo,0)>36500
        and t.fecha =v_fec_fin

        union all
        select d.nro_operacion,d.cod_persona,d.tip_operacion ,'Anticipo Importaciones Verificar rubro y dias de plazo',d.nro_registro
        from sb_crc_operaciones_det d, ge_cuentas g
        where g.nro_cuenta=d.nro_operacion
        and g.cod_modalidad=145
        and d.fecha =v_fec_fin

        union all
        select d.nro_operacion,d.cod_persona,d.tip_operacion ,'Tipo 166 que supera plazo mayor a 1096 dias',d.nro_registro
        from sb_crc_operaciones_det d
        where d.tip_operacion=166
        and d.dia_plazo>1096
        and d.fecha =v_fec_fin;

        CURSOR c_dat_vinculo IS
              select v2.nom_referencia,v2.nro_operacion,v2.tip_operacion,v2.nro_documento,v2.tip_vinculo,v2.cod_persona,v2.nro_registro from sb_crc_vinculos_det v2
                where v2.fecha = v_fec_fin
                and v2.fec_nacimiento is null and v2.apellidos is null
                and (v2.cod_oficina,v2.tip_operacion,v2.nro_operacion,v2.tip_documento,v2.nro_documento,v2.tip_vinculo)in(
                select v.cod_oficina,v.tip_operacion,v.nro_operacion,v.tip_documento,v.nro_documento,v.tip_vinculo
                 from sb_crc_vinculos_det v
                where v.fecha = v_fec_fin
                group by v.cod_oficina,v.tip_operacion,v.nro_operacion,v.tip_documento,v.nro_documento,v.tip_vinculo having count(1)>1);

       rp_gclog              sb_log_crc%ROWTYPE;
       BEGIN

       DELETE sb_log_crc WHERE fecha = v_fec_fin AND nom_referencia in('OPERACION','VINCULOS');
       commit;

       FOR i IN c_datos LOOP

            rp_gclog.fecha          := v_fec_inicio;
            rp_gclog.nom_referencia := 'OPERACION';
            rp_gclog.usu_insercion  := substr(USER, 1, 10);
            rp_gclog.fec_insercion  := SYSDATE;
            rp_gclog.mensaje        := rp_gclog.nom_referencia || ' nro.: ' ||
                                    i.nro_operacion || ', Tipo Operaci?n: ' ||
                                    i.tip_operacion ||' ' ||i.observacion;
            rp_gclog.nro_registro   := i.nro_registro;
            lp_log_crc(rp_gclog);

      END LOOP;

      FOR c IN c_dat_vinculo LOOP

            rp_gclog.fecha          := v_fec_fin;
            rp_gclog.nom_referencia := 'VINCULOS';
            rp_gclog.usu_insercion  := substr(USER, 1, 10);
            rp_gclog.fec_insercion  := SYSDATE;
            rp_gclog.mensaje        := rp_gclog.nom_referencia ||', nro_ope: '||
                                               c.nro_operacion || ', Tipo Ope: '||
                                               c.tip_operacion || ', nro_doc: '||
                                               c.nro_documento || ', tip_vinculo: '||
                                               c.tip_vinculo || ', cod_persona: '||
                                               c.cod_persona ||', Obs: Es una Unipersonal';
            rp_gclog.nro_registro   := c.nro_registro;
            lp_log_crc(rp_gclog);

      END LOOP;

        delete sb_crc_vinculos_det v2
          where v2.fecha = v_fec_fin
          and v2.fec_nacimiento is null and v2.apellidos is null
          and (v2.cod_oficina,v2.tip_operacion,v2.nro_operacion,v2.tip_documento,v2.nro_documento,v2.tip_vinculo)in(
          select v.cod_oficina,v.tip_operacion,v.nro_operacion,v.tip_documento,v.nro_documento,v.tip_vinculo
           from sb_crc_vinculos_det v
          where v.fecha = v_fec_fin
          group by v.cod_oficina,v.tip_operacion,v.nro_operacion,v.tip_documento,v.nro_documento,v.tip_vinculo having count(1)>1);
    END;
   /* Verifica si el cliente esta relacionado con la entidad. */
   FUNCTION fu_cli_rel_entidad(p_cod_persona IN VARCHAR2) RETURN BOOLEAN IS
      v_existe VARCHAR2(1);
   BEGIN
      SELECT '*'
        INTO v_existe
        FROM ge_clientes g
       WHERE g.cod_persona = p_cod_persona
         AND (nvl(g.cod_gru_economico, -1) = fug_obt_pardinamico('COD_GRU_ECO_ENTIDAD') AND
             nvl(fug_obt_pardinamico('SIB_IND_VIN_ESPECIAL'), 'N') = 'N' OR
             fug_obt_pardinamico('SIB_IND_VIN_ESPECIAL') = 'S' AND
             instr(fug_obt_pardinamico('SIB_GRU_VIN_ENTIDAD'),
                    lpad(fue_per_dat_adicional(g.cod_persona, 'COD_GRUPO'), 2, 0)) > 0);
      RETURN TRUE;
   EXCEPTION
      WHEN too_many_rows THEN
         RETURN TRUE;
      WHEN no_data_found THEN
         RETURN FALSE;
      WHEN OTHERS THEN
         RETURN FALSE;
   END;
   -- archivo relaciones 2
   PROCEDURE lp_crc_ins_relaciones2(rp_screl sb_crc_relaciones2_det%ROWTYPE) IS
      v_ins_registro VARCHAR2(1) := 'N';
   BEGIN
      IF rp_screl.cod_persona <> v_cod_per_bco_central THEN
         v_ins_registro := 'S';
      ELSIF rp_screl.cod_persona NOT IN (v_cod_per_entidad, v_cod_per_bco_central) THEN
         v_ins_registro := 'S';
      ELSIF nvl(v_inc_ope_entidad, 'N') = 'S' AND rp_screl.cod_persona = v_cod_per_entidad THEN
         v_ins_registro := 'S';
      END IF;

      IF v_ins_registro = 'S' THEN
         -- inserto los datos en sb_crc_vinculos_det
         INSERT INTO sb_crc_relaciones2_det
            (fecha, nom_referencia, nro_formulario, tip_documento, nro_documento, periodo,
             mto_ingreso, cod_persona)
         VALUES
            (rp_screl.fecha, rp_screl.nom_referencia, rp_screl.nro_formulario,
             rp_screl.tip_documento, rp_screl.nro_documento, rp_screl.periodo, rp_screl.mto_ingreso,
             rp_screl.cod_persona);
      END IF;
   END;

   PROCEDURE lp_obt_dat_ingresos
   (
      p_cod_persona IN ba_personas.cod_persona%TYPE,
      p_mto_ingreso OUT NUMBER,
      p_periodo     OUT DATE
   ) IS
      v_periodo ba_per_dat_adicionales.val_parametro%type;
   BEGIN
      BEGIN
         SELECT SUM(decode(frecuencia, 'M', (importe * 12), importe))
           INTO p_mto_ingreso
           FROM cr_per_ing_egresos e
          WHERE ing_egreso = 'I'
            AND cod_persona = p_cod_persona;
      EXCEPTION
         WHEN no_data_found THEN
            p_mto_ingreso := 0;
         WHEN OTHERS THEN
            p_mto_ingreso := 0;
      END;

      BEGIN
         v_periodo := to_date(fue_per_dat_adicional(p_cod_persona, 'PER_REP_INGRESOS'),
                              'dd/mm/yyyy hh24:mi:ss');
      EXCEPTION
         WHEN OTHERS THEN
            v_periodo := to_date(fue_per_dat_adicional(p_cod_persona, 'PER_REP_INGRESOS'),
                                 'yyyy/mm/dd hh24:mi:ss');
      END;
      IF v_periodo IS NULL THEN
         BEGIN
            SELECT MAX(trunc(fec_modificacion))
              INTO v_periodo
              FROM cr_per_ing_egresos e
             WHERE ing_egreso = 'I'
               AND cod_persona = p_cod_persona;
         EXCEPTION
            WHEN no_data_found THEN
               p_periodo := NULL;
            WHEN OTHERS THEN
               p_periodo := NULL;
         END;
      END IF;
      p_periodo := v_periodo;
    END;

    PROCEDURE pr_crc_gen_relaciones2 IS
       CURSOR c_vinculos IS
          SELECT DISTINCT a.cod_persona
            FROM ge_cla_operaciones a,
                 (SELECT DISTINCT cod_persona, nro_documento, tip_documento
                    FROM sb_crc_vinculos_det c
                   WHERE c.tip_vinculo IN (1)) b,
                 ba_personas c
           WHERE a.cod_persona = b.cod_persona
             AND c.nro_documento = b.nro_documento
          UNION
          SELECT DISTINCT b.cod_persona
            FROM ah_cta_vistas a,
                 (SELECT DISTINCT nro_operacion, nro_documento, tip_documento, cod_persona
                    FROM sb_crc_vinculos_det c
                   WHERE c.tip_vinculo = (1)) b
           WHERE a.nro_cuenta = b.nro_operacion
             AND a.estado NOT IN ('X','C','A')
          UNION
          SELECT DISTINCT b.cod_persona
            FROM ah_cta_certificados a,
                 (SELECT DISTINCT nro_operacion, nro_documento, tip_documento, cod_persona
                    FROM sb_crc_vinculos_det c
                   WHERE c.tip_vinculo = (1)) b
           WHERE a.nro_cuenta = b.nro_operacion
             AND a.estado NOT IN ('T', 'C');
       rg_screl         sb_crc_relaciones2_det%ROWTYPE;
       v_fec_nacimiento ba_per_fisicas.fec_nacimiento%TYPE;
       v_nombres        sb_crc_vinculos_det.nombres%TYPE;
       v_apellidos      sb_crc_vinculos_det.apellidos%TYPE;
    BEGIN
       pag_cal.pr_obt_dat_calendar(1);
       v_fec_actual := pag_cal.fu_obt_fec_actual(1);
       v_fec_fin    := pag_cal.fu_obt_fec_actual(1);
       --
       DELETE sb_crc_relaciones2_det WHERE fecha = v_fec_fin;
       DELETE sb_crc_relaciones_2 WHERE fec_periodo = v_fec_fin;
       COMMIT;
       FOR dt IN c_vinculos LOOP
          rg_screl.mto_ingreso := null;
          rg_screl.nro_documento := null;
          rg_screl.tip_documento := null;

          rg_screl.nom_referencia := 'RELACION2';
          rg_screl.nro_formulario := '019';
          rg_screl.fecha          := v_fec_fin;
          lp_obt_dat_ingresos(dt.cod_persona, rg_screl.mto_ingreso, rg_screl.periodo);
          lp_obt_dat_persona(dt.cod_persona, rg_screl.tip_documento, rg_screl.nro_documento,
                             v_fec_nacimiento, v_nombres, v_apellidos);
          rg_screl.cod_persona := dt.cod_persona;
          -- Inserto el registro en vinculos
          lp_crc_ins_relaciones2(rg_screl);
       END LOOP;
    END;
procedure lp_gen_cat_vta_cartera(p_fecha sb_crc_clasificaciones_det.fecha%type default null)  is --FIELDESK-34615
  v_cat_final                   varchar2(3);
  v_cat_por_prevision           varchar2(3);-- Se utiliza esta variable para encontrar el porcentaje segun su categoria
  v_por_prevision               sb_crc_clasificaciones_det.por_prevision%type;
  v_cat_distintas               varchar2(1);
  v_cat_uno_distintas           varchar2(1);

  -- Obtiene si la cat_riesgo del cliente es distinta entre sus cuentas
  function lf_obt_cat_distintas(p_nro_documento in sb_crc_clasificaciones_det.nro_documento%type,
                                p_fecha in sb_crc_clasificaciones_det.fecha%type )
    return varchar2;
  -- Obtiene si la cat_riesgo del cliente es distinta entre sus cuentas
  function lf_obt_cat_uno_distintas(p_nro_documento in sb_crc_clasificaciones_det.nro_documento%type,
                                p_fecha in sb_crc_clasificaciones_det.fecha%type )
    return varchar2;
  -- Obtiene la categoria riesgo promedio
  function lf_obt_cat_promedio(p_nro_documento in sb_crc_clasificaciones_det.nro_documento%type,
                                p_fecha in sb_crc_clasificaciones_det.fecha%type )
    return varchar2;
  -- Obtener la categoría del clientes para categoría riesgo
  function lf_obt_cat_riesgo(p_nro_documento in sb_crc_clasificaciones_det.nro_documento%type,
                                p_fecha in sb_crc_clasificaciones_det.fecha%type )

   return varchar2;

  cursor personas is
    select a.nro_documento, a.cod_persona, a.fecha, a.cat_riesgo
      from sb_crc_clasificaciones_det a
     where a.mto_vta_cartera <> 0
     and a.fecha= p_fecha; -- Codeudoria general personas

  procedure pr_gen_datos_tmp is
    begin
    -- Creacion de tablas temporales sb_crc_cli_vta_cartera_tmp
    insert into sb_crc_cli_vta_cartera_tmp
      (select s.nom_referencia,
              s.fecha,
              s.nro_operacion,
              p.nro_cuenta,
              s.cod_modulo,
              s.cod_modalidad,
              s.tip_operacion,
              v.nro_documento,
              s.sal_capital,
              s.cla_riesgo,
              to_char(v.tip_vinculo) tip_vinculo
         from sb_crc_saldos_det   s,
              sb_crc_vinculos_det v,
              sb_crc_vta_carteras p
        where s.nro_operacion = v.nro_operacion
          and s.tip_operacion = v.tip_operacion
          and v.cod_modulo <> '3'
          and s.nom_referencia = 'SALDOSV'
          and v.tip_vinculo in (002, 004, 005, 006, 007, 010)
          and s.nro_operacion = p.nro_cuenta_bt
          and s.fecha = p_fecha

       union
       select sd.nom_referencia,
              sd.fecha,
              sd.nro_operacion,
              g.nro_cuenta,
              sd.cod_modulo,
              sd.cod_modalidad,
              sd.tip_operacion,
              p.nro_documento,
              sd.sal_capital,
              sd.cla_riesgo,
              '1' vip_vinculo
         from sb_crc_saldos_det sd, sb_crc_vta_carteras g, ba_personas p
        where g.nro_cuenta_bt = pae_uti.fu_obt_valor(fus_obt_cta_operacion(sd.nro_operacion,
                                                                           sd.cod_modulo),1)
          and g.nro_documento = p.nro_documento
          and sd.cod_modulo <> '3'
          and sd.fecha = p_fecha);

    -- Creacion de tabla temporal sb_crc_ope_vta_cartera_tmp
    insert into sb_crc_ope_vta_cartera_tmp
      (select c.fecha,
              c.nro_operacion,
              c.sal_capital,
              c.cla_riesgo,
              decode(c.cla_riesgo, '1a', 1.1, '1b', 1.2, c.cla_riesgo) cla_riesgo_num,
              nvl(e.nro_documento, d.nro_documento) nro_documento,
              e.cod_persona
         from sb_crc_saldos_det c, sb_crc_vta_carteras d, ba_personas e
        where c.nro_operacion = d.nro_cuenta_bt
          and c.nom_referencia = 'SALDOSV'
          and d.estado_vta_cartera = 'C'
          and d.cod_persona = e.cod_persona
          and c.fecha = p_fecha
          and fu_inc_ope_vta_medidas(e.nro_documento,
                                     c.nro_operacion,
                                     c.fecha) = 'S'
          and not exists
        (select 1
                 from sb_crc_saldos_det a, ge_cla_operaciones b
                where pae_uti.fu_obt_valor(a.nro_operacion, 1) =
                      b.nro_cuenta
                  and a.nom_referencia = 'SALDOS'
                  and b.cod_modulo in (6, 15)
                  and b.cod_persona = e.cod_persona
                  and a.fecha = p_fecha
                  and exists (select '1'
                         from sb_crc_clasificaciones_det e
                        where b.cod_persona = e.cod_persona
                          and a.fecha = e.fecha
                          and e.mto_vta_cartera <> 0)
               union
               select 1
                 from sb_crc_saldos_det  a,
                      ge_cla_operaciones b,
                      ta_tarjetas        c
                where a.nro_operacion = c.nro_tarjeta
                  and b.nro_cuenta = c.nro_cuenta
                  and a.nom_referencia = 'SALDOS'
                  and b.cod_modulo in (5)
                  and b.cod_persona = e.cod_persona
                  and a.fecha = p_fecha
                  and exists (select '1'
                         from it.sb_crc_clasificaciones_det e
                        where b.cod_persona = e.cod_persona
                          and a.fecha = e.fecha
                          and e.mto_vta_cartera <> 0)));

    end;


  -- Obtener si la persona tiene cat_automaticas distintas entre sus  mt
  function lf_obt_cat_distintas(p_nro_documento in sb_crc_clasificaciones_det.nro_documento%type,
                                p_fecha in sb_crc_clasificaciones_det.fecha%type )
    return varchar2 is
    v_nro_documento sb_crc_clasificaciones_det.nro_documento%type;
    valor     varchar2(1);
    -- Recupera si la cuenta tiene cat_riesgo distinta entre sus cuentas
  begin
    select nro_documento,
           case
             when count(distinct cla_riesgo) >= 2 then
              'S'
             else
              'N'
           end as xx
      into v_nro_documento, valor
      from It.sb_crc_ope_vta_cartera_tmp b
     where b.nro_documento = p_nro_documento
       and b.fecha = p_fecha
     group by b.nro_documento;

    return(valor);

  exception
    when others then
      return('N');
  end;

   function lf_obt_cat_uno_distintas(p_nro_documento in sb_crc_clasificaciones_det.nro_documento%type,
                                  p_fecha in sb_crc_clasificaciones_det.fecha%type )
      return varchar2 is
      v_nro_documento sb_crc_clasificaciones_det.nro_documento%type;
      valor     varchar2(1);
      -- Recupera si la cuenta tiene cat_riesgo distinta entre sus cuentas dentro del rango del 1, 1a, 1b
   begin
     select nro_documento,
            case
              when count(distinct cla_riesgo) >= 2 and
                   max(distinct b.cla_riesgo_num) < 2 then
               'S'
              else
               'N'
            end as xx
       into v_nro_documento, valor
       from sb_crc_ope_vta_cartera_tmp b
      where b.nro_documento = p_nro_documento
        and b.fecha = p_fecha
      group by b.nro_documento;

    return(valor);

  exception
    when others then
      return('N');
  end;

  -- Obtiene la cat_riesgo promedio si el cliente tiene cat_riesgo distintas
  function lf_obt_cat_promedio(p_nro_documento in sb_crc_clasificaciones_det.nro_documento%type,
                               p_fecha in sb_crc_clasificaciones_det.fecha%type)
    return varchar2 is
    p_documento sb_crc_clasificaciones_det.nro_documento%type;
    valor       varchar2(3);

  -- Recupera el promedio de la cat_riegos
  begin
   select nro_documento, round(sum(cat_pon), 0) cat_final
     into p_documento, valor
     from (select nro_documento,
                  round(((sal_capital / deuda_total) * cla_riesgo), 2) cat_pon
             from (select f.nro_documento,
                          f.nro_operacion,
                          f.cla_riesgo_num cla_riesgo,
                          f.sal_capital,
                          (select sum(b.sal_capital)
                             from sb_crc_ope_vta_cartera_tmp b
                            where b.fecha = p_fecha
                              and b.nro_documento = p_nro_documento) deuda_total

                     from sb_crc_ope_vta_cartera_tmp f
                    where f.fecha = p_fecha
                      and f.nro_documento = p_nro_documento) c)
    group by nro_documento;

   if (nvl(valor,1)=1) then
    valor:= '1b';
   end if;

    return(valor);

  exception
    when others then
      return('1');
  end;

  -- Obtener la categoría de riesgo de clientes para categoría 1(uno). resolución n°37
  function lf_obt_cat_riesgo(p_nro_documento in sb_crc_clasificaciones_det.nro_documento%type,
                           p_fecha in sb_crc_clasificaciones_det.fecha%type)
  return varchar2 as
  v_categoria sb_crc_clasificaciones_det.cat_riesgo%type;
  begin

  select max(f.cla_riesgo)
    into v_categoria
    from sb_crc_ope_vta_cartera_tmp f
   where f.nro_documento = p_nro_documento
     and f.fecha = p_fecha;

    return v_categoria;
  exception
    when others then
      v_categoria := null;
      return v_categoria;
  end;

  begin
   -- Carga tabla temporal
    pr_gen_datos_tmp;
  for reg in personas Loop
    v_cat_final         := null;
    v_cat_por_prevision := null;
    v_cat_distintas     := null;
    v_por_prevision     := null;
    v_cat_uno_distintas := null;
    -- Carga variable
    v_cat_distintas := lf_obt_cat_distintas(reg.nro_documento, reg.fecha);

    if v_cat_distintas = 'S' then

      v_cat_uno_distintas := lf_obt_cat_uno_distintas(reg.nro_documento, reg.fecha);

      if v_cat_uno_distintas ='S' then
       v_cat_final := lf_obt_cat_riesgo(reg.nro_documento, reg.fecha);
      else
       v_cat_final := lf_obt_cat_promedio(reg.nro_documento, reg.fecha); --aca debe hacer la formula rara
      end if;

    else

      v_cat_final := lf_obt_cat_riesgo(reg.nro_documento, reg.fecha);

    end if;

    if v_cat_final is null then
      v_cat_final := reg.cat_riesgo;
    end if;

    v_cat_por_prevision := (case
                             when v_cat_final = '1a' then
                                   1.1
                             when v_cat_final = '1b' then
                                   1.2
                             else
                                  v_cat_final

                              end);

    v_por_prevision := fus_obt_por_prevision(v_cat_por_prevision);


    update sb_crc_clasificaciones_det a
       set a.cat_riesgo    = trim(v_cat_final),
           a.por_prevision = v_por_prevision
     where a.nro_documento = reg.nro_documento
       and a.fecha = p_fecha;

   end loop;
end;

procedure pr_gen_cla_vta_cartera( p_tip_proceso in varchar2 default 'M' ) is --FIELDESK-34615

       rp_gclog                sb_log_crc%ROWTYPE;
       rp_sccla                sb_crc_clasificaciones_det%ROWTYPE;
       v_mensaje               varchar2(1000);
       v_cat_riesgo            sb_crc_clasificaciones_det.cat_riesgo%type;
       v_cat_final             sb_crc_clasificaciones_det.cat_riesgo%type;
       v_tip_documento         sb_crc_vinculos_det.tip_documento%type;
       v_nro_documento         sb_crc_vinculos_det.nro_documento%type;
       v_fec_nacimiento        sb_crc_vinculos_det.fec_nacimiento%type;
       v_nombres               sb_crc_vinculos_det.nombres%type;
       v_apellidos             sb_crc_vinculos_det.apellidos%type;
       v_nro_registro          sb_crc_operaciones.tot_registro%type := 0;
       v_fec_clasifica         date := to_date(fug_obt_pardinamico('FEC_CLA_VTA_CARTERA'),'dd/mm/yyyy');
       v_max_cat_riesgo        varchar2(5);
       v_tip_documento2        sb_crc_vinculos_det.tip_documento%type;
       v_nro_documento2        sb_crc_vinculos_det.nro_documento%type;
       v_fec_nacimiento2       sb_crc_vinculos_det.fec_nacimiento%type;
       v_nombres2              sb_crc_vinculos_det.nombres%type;
       v_apellidos2            sb_crc_vinculos_det.apellidos%type;

        cursor c_cla_vta_cartera is
           -- Datos mensuales
           select a.cod_persona,
                  max(nvl(a.cat_cliente, a.cat_cliente_clasif)) cat_cliente,
                  sum(a.sal_capital) sal_capital
             from sb_crc_vta_carteras a
            where nvl(a.estado_vta_cartera, 'N') = 'C'
            group by a.cod_persona;

       procedure lp_crc_gen_dat_clasifica(p_tip_periodo in varchar2 default 'D') is
       begin
         pag_cal.pr_obt_dat_calendar(1);
         v_fec_actual  :=pag_cal.fu_obt_fec_actual(1);
         v_fec_inicio  :=pag_cal.fu_obt_fec_actual(1);
         v_fec_fin     :=pag_cal.fu_obt_fec_actual(1);
         v_fec_proxima := last_day(v_fec_actual);

         if p_tip_periodo = 'Q' then
            if to_number(to_char(v_fec_actual, 'DD')) > 15 then
               -- Si la fecha de proceso es mayor a 15 tomar la primera quincena para procesar del 1 al 15
               v_fec_inicio := to_date('01' || to_char(v_fec_actual, 'mmyyyy'), 'ddmmyyyy');
               v_fec_fin    := to_date('15' || to_char(v_fec_actual, 'mmyyyy'), 'ddmmyyyy');
            else
               -- Si la fecha de proceso es menor a 15 tomar la segunda quincena para procesar del 16
               -- Al ultimo dia del mes anterior a la fecha de proceso.
               v_fec_inicio := to_date('16' || to_char(add_months(v_fec_actual, -1), 'mmyyyy'),
                                       'ddmmyyyy');
               v_fec_fin    := last_day(v_fec_inicio);
            end if;
         elsif p_tip_periodo = 'M' then
            v_fec_inicio := pag_cal.g_pri_dia_mes;
            v_fec_fin    := pag_cal.g_ult_dia_mes;
         end if;

         delete sb_crc_clasificaciones_det d
          where d.fecha = v_fec_fin
            and d.nom_referencia = 'CLASIFICAV';
         begin
           update sb_crc_clasificaciones_det d
              set d.mto_vta_cartera = 0,
                  d.mto_rie_contingente=0
            where d.fecha = v_fec_fin
              and d.nom_referencia = 'CLASIFICA'
              and nvl(d.mto_vta_cartera, 0) > 0;
         exception
           when others then
             null;
         end;
         begin
            select max(nro_registro)
              into v_nro_registro
              from sb_crc_clasificaciones_det
             where fecha = v_fec_fin
               and nom_referencia = 'CLASIFICA';
         exception
            when others then
               v_nro_registro := 0;
         end;
         if v_nro_registro = 0 then
            delete sb_crc_clasificaciones where fec_periodo between v_fec_inicio and v_fec_fin;
         end if;
         delete sb_log_crc where fecha = v_fec_fin and nom_referencia = 'CLASIFICAV';
         commit;
       end;

       function lf_exi_clasifica(p_cod_persona in sb_crc_clasificaciones_det.cod_persona%type) return varchar2 as
         v_exi_clasifica varchar2(1);
       begin
         select 'S'
           into v_exi_clasifica
           from sb_crc_clasificaciones_det d
          where d.fecha = v_fec_fin
            and d.nom_referencia = 'CLASIFICA'
            and d.cod_persona = p_cod_persona;
         return v_exi_clasifica;
       exception
         when others then
           return 'N';
       end;

    begin
       lp_crc_gen_dat_clasifica(p_tip_proceso);
       for i in c_cla_vta_cartera loop
          -- Se inserta la persona solo si ya no esta en el archivo de clasifica(volvio a ser cliente)
          if lf_exi_clasifica(i.cod_persona) = 'N' then
             v_mensaje               := null;
             rp_sccla.fecha          := v_fec_fin; -- Fecha
             rp_sccla.nom_referencia := 'CLASIFICAV'; -- Nombre Referencia Archivo
             rp_sccla.nro_formulario := '011'; -- Formulario (011)
             rp_sccla.cod_persona    := i.cod_persona;
             lp_obt_dat_persona(i.cod_persona, v_tip_documento, v_nro_documento, v_fec_nacimiento,
                                v_nombres, v_apellidos);

               v_tip_documento2  := null;
               v_nro_documento2  := null;
               v_nombres2        := null;
               v_apellidos2      := null;
               v_fec_nacimiento2 := null;

             if v_tip_documento is null or  v_nro_documento is null or v_fec_nacimiento is null or
               v_nombres is null or v_apellidos is null then
                  begin
                  select a.tip_documento,a.nro_documento,a.nombres,a.apellidos,a.fec_nacimiento
                     into v_tip_documento2,v_nro_documento2,v_nombres2,v_apellidos2,v_fec_nacimiento2
                    from sb_crc_vta_carteras a
                   where nvl(a.estado_vta_cartera, 'N') = 'C'
                     and a.cod_persona = i.cod_persona
                     and rownum = 1;
                  exception
                     when no_data_found then
                      v_tip_documento2  := null;
                      v_nro_documento2  := null;
                      v_nombres2        := null;
                      v_apellidos2      := null;
                      v_fec_nacimiento2 := null;
                    end;
             end if;

             if nvl(v_tip_documento,v_tip_documento2) is not null then
                rp_sccla.tip_documento := nvl(v_tip_documento,v_tip_documento2); -- Tipo de Documento (CI=Cedula de Identidad / CRC=Codigo de Persona no residente / CRP=Carnet de Residencia Permanente / RUC=Regsitro Unico Contribuyente)
             else
                rp_sccla.tip_documento := null;
                v_mensaje := v_mensaje || ', Tipo Documento es nulo';
             end if;
             if nvl(v_nro_documento,v_nro_documento2) is not null then
                rp_sccla.nro_documento := nvl(v_nro_documento,v_nro_documento2); -- Numero de Documento de Identidad
             else
                rp_sccla.nro_documento := null;
                v_mensaje := v_mensaje || ', Numero de Documento es nulo';
             end if;
             if nvl(v_fec_nacimiento,v_fec_nacimiento2) is not null then
                rp_sccla.fec_nacimiento := nvl(v_fec_nacimiento,v_fec_nacimiento2); -- Fecha de nacimiento AAAAMMDD
             else
                rp_sccla.fec_nacimiento := null;
                v_mensaje := v_mensaje || ', Fecha de Nacimiento es nulo';
             end if;
             if nvl(v_nombres,v_nombres2) is not null then
                rp_sccla.nombres := nvl(v_nombres,v_nombres2); -- Nombres
             else
                rp_sccla.nombres := null;
                v_mensaje := v_mensaje || ', Nombres es nulo';
             end if;
             if nvl(v_apellidos,v_apellidos2) is not null then
                rp_sccla.apellidos := nvl(v_apellidos,v_apellidos2); -- Apellidos
             else
                rp_sccla.apellidos := null;
                v_mensaje := v_mensaje || ', Apellidos es nulo';
             end if;
             -- Clasificacion de Riesgo de la Persona
             v_cat_riesgo := i.cat_cliente;
             -- Si la Cat. es 1 verifica si tiene operaciones con mora Cat. 1a o 1b (Res. 37)
             if v_cat_riesgo = '1' then
               v_cat_riesgo := i.cat_cliente;

             end if;
             if v_cat_riesgo is null then
                v_mensaje := v_mensaje || ',  La categoria del Cliente es Nula. Se ha asignado como categoria por defecto "1" en el Archivo Clasifica. Favor Verificar!.';
             end if;
             -- Ajuste para calcular procentaje prevision para operaciones con mora Cat. 1a o 1b

             v_max_cat_riesgo := (case
                                   when v_cat_riesgo = '1a' then
                                    1.1
                                   when v_cat_riesgo = '1b' then
                                    1.2
                                    else
                                    v_cat_riesgo

                                    end);

             v_cat_final                    :=i.cat_cliente;
             rp_sccla.cat_riesgo            := rtrim(v_cat_final);
             rp_sccla.por_prevision         := fus_obt_por_prevision(v_max_cat_riesgo); --- Porcentaje de Prevision a partir de la Categoria de Riesgo
             rp_sccla.cat_subjetiva         := null;
             rp_sccla.tot_tc                := 0;
             rp_sccla.tot_garantia          := 0;
             rp_sccla.tot_cap_pri_prevision := 0;
             rp_sccla.tot_int_pri_prevision := 0;
             rp_sccla.tot_cap_seg_prevision := 0;
             rp_sccla.tot_int_seg_prevision := 0;
             rp_sccla.mto_riesgo            := 0;
             rp_sccla.mto_vta_cartera       := i.sal_capital;-- se reutiliza el campo para informar la cartera vendida
             rp_sccla.mto_rie_contingente   := i.sal_capital;
             rp_sccla.mto_deu_incobrable    :=0;
             rp_sccla.tot_sr                := 0;
             rp_sccla.sal_cap_vencido       := 0;
             rp_sccla.sal_int_vencido       := 0;
             rp_sccla.tot_dc                := 0;
             rp_sccla.tot_tr                := 0;
             rp_sccla.tot_dr                := 0;
             rp_sccla.tot_er                := 0;
             v_nro_registro                 := v_nro_registro + 1;
             rp_sccla.nro_registro          := v_nro_registro; -- Nro. de Registro
             -- Inserta la clasificacion
             lp_ins_crc_clasificaciones(rp_sccla); -- insercion de la clasificacion
             if v_mensaje is not null then
                rp_gclog.fecha          := rp_sccla.fecha;
                rp_gclog.nom_referencia := rp_sccla.nom_referencia;
                rp_gclog.usu_insercion  := substr(USER, 1, 10);
                rp_gclog.fec_insercion  := SYSDATE;
                rp_gclog.mensaje        := 'ERROR: Persona = ' || i.cod_persona || ': ' || v_mensaje ||
                                           '; Nro. Registro: ' || rp_sccla.nro_registro;
                rp_gclog.nro_registro   := rp_sccla.nro_registro;
                lp_log_crc(rp_gclog);
             end if;
          else
             begin
               update sb_crc_clasificaciones_det c
                  set c.mto_vta_cartera = i.sal_capital,
                      c.mto_rie_contingente=i.sal_capital
                where c.fecha = v_fec_fin
                  and c.nom_referencia = 'CLASIFICA'
                  and c.cod_persona = i.cod_persona;
             exception
               when others then
                 null;
             end;
          end if;
       end loop;

       lp_act_tot_registro(v_fec_fin, 'SB_CRC_CLASIFICACIONES', 'CLASIFICAV');
       commit;
       lp_gen_cat_vta_cartera(v_fec_fin); -- Recategorizacion de titulares de venta
    exception
     when others then
       raise_application_error(-20001, 'Error en la generacion de ClasificaV '||sqlerrm);

    end;
 procedure pr_gen_cla_vta_car_codeudoria( p_tip_proceso in varchar2 default 'M' ) is --FIELDESK-34615

       rp_gclog                sb_log_crc%ROWTYPE;
       rp_sccla                sb_crc_clasificaciones_det%ROWTYPE;
       v_mensaje               varchar2(1000);
       v_cat_riesgo            sb_crc_clasificaciones_det.cat_riesgo%type;
       v_cat_final             sb_crc_clasificaciones_det.cat_riesgo%type;
       v_tip_documento         sb_crc_vinculos_det.tip_documento%type;
       v_nro_documento         sb_crc_vinculos_det.nro_documento%type;
       v_fec_nacimiento        sb_crc_vinculos_det.fec_nacimiento%type;
       v_nombres               sb_crc_vinculos_det.nombres%type;
       v_apellidos             sb_crc_vinculos_det.apellidos%type;
       v_nro_registro          sb_crc_operaciones.tot_registro%type := 0;
       v_fec_clasifica         date := to_date(fug_obt_pardinamico('FEC_CLA_VTA_CARTERA'),'dd/mm/yyyy');
       v_max_cat_riesgo        varchar2(5);

       cursor c_cla_vta_cartera is

           select a.fecha,
                   a.nom_referencia,
                   a.nro_formulario,
                   a.nro_registro,
                   a.tip_documento,
                   a.nro_documento,
                   a.fec_nacimiento,
                   a.nombres,
                   a.apellidos,
                   a.cat_riesgo,
                   a.cat_subjetiva,
                   a.cat_rie_fideicomiso,
                   a.por_prevision,
                   a.mto_rie_contingente,
                   a.mto_riesgo,
                   a.sal_cap_vencido,
                   a.sal_int_vencido,
                   a.tot_garantia,
                   a.tot_cap_pri_prevision,
                   a.tot_cap_seg_prevision,
                   a.tot_int_pri_prevision,
                   a.tot_int_seg_prevision,
                   a.tot_tc,
                   a.tot_dc,
                   a.tot_tr,
                   a.tot_dr,
                   a.tot_er,
                   a.tot_sr,
                   a.cod_persona,
                   a.cat_rie_vta_cartera,
                   a.tot_tf,
                   a.mto_vta_cartera,
                   a.mto_deu_incobrable,
                   a.estado
            from  sb_crc_vta_codeudoria a
            where nvl(a.estado,'N')='C';

       procedure lp_crc_gen_dat_clasifica(p_tip_periodo in varchar2 default 'D') is
       begin
         pag_cal.pr_obt_dat_calendar(1);
         v_fec_actual  := pag_cal.fu_obt_fec_actual(1);
         v_fec_inicio  := pag_cal.fu_obt_fec_actual(1);
         v_fec_fin     := pag_cal.fu_obt_fec_actual(1);
         v_fec_proxima := last_day(v_fec_actual);
         if p_tip_periodo = 'Q' then
            if to_number(to_char(v_fec_actual, 'DD')) > 15 then
               -- Si la fecha de proceso es mayor a 15 tomar la primera quincena para procesar del 1 al 15
               v_fec_inicio := to_date('01' || to_char(v_fec_actual, 'mmyyyy'), 'ddmmyyyy');
               v_fec_fin    := to_date('15' || to_char(v_fec_actual, 'mmyyyy'), 'ddmmyyyy');
            else
               -- Si la fecha de proceso es menor a 15 tomar la segunda quincena para procesar del 16
               -- Al ultimo dia del mes anterior a la fecha de proceso.
               v_fec_inicio := to_date('16' || to_char(add_months(v_fec_actual, -1), 'mmyyyy'),
                                       'ddmmyyyy');
               v_fec_fin    := last_day(v_fec_inicio);
            end if;
         elsif p_tip_periodo = 'M' then
            v_fec_inicio := pag_cal.g_pri_dia_mes;
            v_fec_fin    := pag_cal.g_ult_dia_mes;
         end if;

         begin
            select max(nro_registro)
              into v_nro_registro
              from sb_crc_clasificaciones_det
             where fecha = v_fec_fin;
         exception
            when others then
               v_nro_registro := 0;
         end;

       end;

       function lf_exi_clasifica(p_cod_persona in sb_crc_clasificaciones_det.cod_persona%type,
                                 p_nro_documento in sb_crc_clasificaciones_det.nro_documento%type,
                                 p_tip_documento in sb_crc_clasificaciones_det.tip_documento%type) return varchar2 as
         v_exi_clasifica varchar2(1);
       begin
         select 'S'
           into v_exi_clasifica
           from sb_crc_clasificaciones_det d
          where d.fecha = v_fec_fin
            and d.nom_referencia in ('CLASIFICA','CLASIFICAV')
            and d.cod_persona = p_cod_persona;
            return v_exi_clasifica;
       exception
         when no_data_found then
          begin
           select 'S'
           into v_exi_clasifica
           from sb_crc_clasificaciones_det d
          where d.fecha = v_fec_fin
            and d.nom_referencia in ('CLASIFICA','CLASIFICAV')
            and d.nro_documento = p_nro_documento
            and d.tip_documento = p_tip_documento;
            return v_exi_clasifica;
           exception
           when others then
           return 'N';
           end;
         when others then
           return 'N';
       end;

    begin
       lp_crc_gen_dat_clasifica(p_tip_proceso);
       for i in c_cla_vta_cartera loop
          -- Se inserta la persona solo si ya no esta en el archivo de clasifica(volvio a ser cliente)
          if lf_exi_clasifica(i.cod_persona,i.nro_documento,i.tip_documento) = 'N' then
             v_mensaje               := null;
             rp_sccla.fecha          := v_fec_fin; -- Fecha
             rp_sccla.nom_referencia := 'CLASIFICAC'; -- Nombre Rerencia Archivo
             rp_sccla.nro_formulario := '011'; -- Formulario (011)
             rp_sccla.cod_persona    := i.cod_persona;
             lp_obt_dat_persona(i.cod_persona, v_tip_documento, v_nro_documento, v_fec_nacimiento,
                                v_nombres, v_apellidos);
             if nvl(i.tip_documento,v_tip_documento) is not null then
                rp_sccla.tip_documento := nvl(i.tip_documento,v_tip_documento); -- Tipo de Documento (CI=Cedula de Identidad / CRC=Codigo de Persona no residente / CRP=Carnet de Residencia Permanente / RUC=Regsitro Unico Contribuyente)
             else
                rp_sccla.tip_documento := null;
                v_mensaje := v_mensaje || ', Tipo Documento es nulo';
             end if;
             if nvl(i.nro_documento,v_nro_documento) is not null then
                rp_sccla.nro_documento := nvl(i.nro_documento,v_nro_documento); -- Numero de Documento de Identidad
             else
                rp_sccla.nro_documento := null;
                v_mensaje := v_mensaje || ', Numero de Documento es nulo';
             end if;
             if nvl(i.fec_nacimiento,v_fec_nacimiento) is not null then
                rp_sccla.fec_nacimiento := nvl(i.fec_nacimiento,v_fec_nacimiento); -- Fecha de nacimiento AAAAMMDD
             else
                rp_sccla.fec_nacimiento := null;
                v_mensaje := v_mensaje || ', Fecha de Nacimiento es nulo';
             end if;
             if nvl(i.nombres,v_nombres) is not null then
                rp_sccla.nombres := nvl(i.nombres,v_nombres); -- Nombres
             else
                rp_sccla.nombres := null;
                v_mensaje := v_mensaje || ', Nombres es nulo';
             end if;
             if nvl(i.apellidos,v_apellidos) is not null then
                rp_sccla.apellidos := nvl(i.apellidos,v_apellidos); -- Apellidos
             else
                rp_sccla.apellidos := null;
                v_mensaje := v_mensaje || ', Apellidos es nulo';
             end if;
             -- Clasificacion de Riesgo de la Persona
             v_cat_riesgo := i.cat_riesgo;
             -- Si la Cat. es 1 verifica si tiene operaciones con mora Cat. 1a o 1b (Res. 37)
             if v_cat_riesgo = '1' then
               v_cat_riesgo := i.cat_riesgo;

             end if;
             if v_cat_riesgo is null then
                v_mensaje := v_mensaje || ',  La categoria del Cliente es Nula. Se ha asignado como categoria por defecto "1" en el Archivo Clasifica. Favor Verificar!.';
             end if;

             -- Ajuste para calcular procentaje prevision para operaciones con mora Cat. 1a o 1b

             v_max_cat_riesgo := (case
                                   when v_cat_riesgo = '1a' then
                                    1.1
                                   when v_cat_riesgo = '1b' then
                                    1.2
                                    else
                                    v_cat_riesgo

                                    end);


             v_cat_final:=i.cat_riesgo;

             rp_sccla.cat_riesgo            := v_cat_final;
             rp_sccla.por_prevision         := fus_obt_por_prevision(v_max_cat_riesgo);
             rp_sccla.cat_subjetiva         := null;
             rp_sccla.tot_tc                := 0;
             rp_sccla.tot_garantia          := 0;
             rp_sccla.tot_cap_pri_prevision := 0;
             rp_sccla.tot_int_pri_prevision := 0;
             rp_sccla.tot_cap_seg_prevision := 0;
             rp_sccla.tot_int_seg_prevision := 0;
             rp_sccla.mto_riesgo            := 0;
             rp_sccla.mto_vta_cartera       := 0;
             rp_sccla.mto_rie_contingente   := 0;
             rp_sccla.mto_deu_incobrable    := 0;
             rp_sccla.tot_sr                := i.tot_sr;
             rp_sccla.sal_cap_vencido       := 0;
             rp_sccla.sal_int_vencido       := 0;
             rp_sccla.tot_dc                := 0;
             rp_sccla.tot_tr                := 0;
             rp_sccla.tot_dr                := 0;
             rp_sccla.tot_er                := 0;
             v_nro_registro                 := v_nro_registro + 1;
             rp_sccla.nro_registro          := v_nro_registro; -- Nro. de Registro
             -- Inserta la clasificacion
             lp_ins_crc_clasificaciones(rp_sccla); -- Insercion de la clasificacion
             if v_mensaje is not null then
                rp_gclog.fecha          := rp_sccla.fecha;
                rp_gclog.nom_referencia := rp_sccla.nom_referencia;
                rp_gclog.usu_insercion  := substr(USER, 1, 10);
                rp_gclog.fec_insercion  := SYSDATE;
                rp_gclog.mensaje        := 'ERROR: Persona = ' || i.cod_persona || ': ' || v_mensaje ||
                                           '; Nro. Registro: ' || rp_sccla.nro_registro;
                rp_gclog.nro_registro   := rp_sccla.nro_registro;
                lp_log_crc(rp_gclog);
             end if;
          else -- Actualizamos el tot_sr(codeudoria) si ya existe en los registros de la fecha
             begin
               update sb_crc_clasificaciones_det c
                  set c.tot_sr = nvl(c.tot_sr,0)+i.tot_sr
                where c.fecha = v_fec_fin
                  and c.nom_referencia in ('CLASIFICA','CLASIFICAV')
                  and c.cod_persona = i.cod_persona;
             exception
               when no_data_found then
                 begin
                   update sb_crc_clasificaciones_det c
                    set c.tot_sr = nvl(c.tot_sr,0)+i.tot_sr
                  where c.fecha = v_fec_fin
                    and c.nom_referencia in ('CLASIFICA','CLASIFICAV')
                    and c.Nro_Documento = i.Nro_Documento
                    and c.tip_documento= i.tip_documento;
                 exception
                 when others then
                      null;
                 end;
               when others then
                 null;
             end;
          end if;
       end loop;

       lp_act_tot_registro(v_fec_fin, 'SB_CRC_CLASIFICACIONES', 'CLASIFICAV');
    exception
     when others then
       raise_application_error(-20001, 'Error en la generacion de CLASIFICAV '||sqlerrm);
    end;
function fu_inc_ope_vta_medidas
(
   p_nro_documento in sb_crc_vinculos_det.nro_documento%type,
   p_nro_cuenta    in ge_cta_clientes.nro_cuenta%type,
   p_fecha         in sb_crc_saldos_det.fecha%type
) return varchar2 is --FIELDESK-34615
   v_incluir     varchar2(1);
begin
   -- Incluir el prestamo de medida transitoria solo si supera la categoría del cliente,
   -- y no tiene otro tipo de operacion
   select distinct 'S'
     into v_incluir
     from sb_crc_cli_vta_cartera_tmp s
    where s.nro_documento = p_nro_documento
      and s.nro_operacion = p_nro_cuenta
      and s.fecha=p_fecha
      and (
           (exists (select 1
                     from ge_par_dinamicos p
                    where p.parametro in ('PRE_MAD_EXC_PYMES', 'PRE_MAD_EXCEPCION')
                      and p.cod_modalidad = s.cod_modalidad
                      and p.cod_modulo = s.cod_modulo
                      and nvl(p.val_parametro, 'N') = 'S') and not exists
           (select 1 -- Todos los miembros tienen solo ope de ME.
              from sb_crc_cli_vta_cartera_tmp s
             where s.nro_documento = p_nro_documento
               and S.FECHA= p_fecha
               and s.nom_referencia='SALDOSV'
               and not exists (select 1
                      from ge_par_dinamicos p
                     where p.parametro in ('PRE_MAD_EXC_PYMES', 'PRE_MAD_EXCEPCION')
                       and p.cod_modalidad = s.cod_modalidad
                       and p.cod_modulo = s.cod_modulo
                       and nvl(p.val_parametro, 'N') = 'S'))) or -- No es de medida transitoria
           (not exists (select 1
                         from ge_par_dinamicos p
                        where p.parametro in ('PRE_MAD_EXC_PYMES', 'PRE_MAD_EXCEPCION')
                          and p.cod_modalidad = s.cod_modalidad
                          and p.cod_modulo = s.cod_modulo
                          and nvl(p.val_parametro, 'N') = 'S')
                 and not exists (select  1
                                   from ge_cta_dat_adicionales a
                                  where a.parametro in ('PRE_RRR_CTA_MBT','PRE_RRR_CTA_MBT1','PRE_RRR_CTA_MBT2')
                                    and a.nro_cuenta =  pae_uti.fu_obt_valor(fus_obt_cta_operacion(s.nro_cuenta,s.cod_modulo), 1))) or
           (not exists (select 1
                         from ge_par_dinamicos p
                        where p.parametro in ('PRE_MAD_EXC_PYMES', 'PRE_MAD_EXCEPCION')
                          and p.cod_modalidad = s.cod_modalidad
                          and p.cod_modulo = s.cod_modulo
                          and nvl(p.val_parametro, 'N') = 'S')
                       and exists (select 1
                                 from ge_cta_dat_adicionales a
                                where a.parametro in ('PRE_RRR_CTA_MBT','PRE_RRR_CTA_MBT1','PRE_RRR_CTA_MBT2')
                                  and a.nro_cuenta = pae_uti.fu_obt_valor(fus_obt_cta_operacion(s.nro_cuenta,s.cod_modulo), 1))
                       and not exists (select 1 -- Todos los miembros tienen solo ope de ME.
                               from sb_crc_cli_vta_cartera_tmp  xx
                              where xx.nro_documento = p_nro_documento
                                 and xx.fecha=p_fecha
                                 and xx.nro_operacion <> s.nro_operacion
                                 and xx.nom_referencia='SALDOSV'
                                 -- Que no exista como MT madre
                                 and not exists (select 1
                                 from ge_cta_dat_adicionales a
                                 where a.parametro in ('PRE_RRR_CTA_MBT','PRE_RRR_CTA_MBT1','PRE_RRR_CTA_MBT2')
                                 and a.nro_cuenta = pae_uti.fu_obt_valor(fus_obt_cta_operacion(XX.nro_cuenta,XX.cod_modulo), 1))
                                 and 'N' = (select nvl(max(pp.val_parametro), 'N')
                                            from ge_par_dinamicos pp
                                           where pp.parametro in ('PRE_MAD_EXC_PYMES', 'PRE_MAD_EXCEPCION')
                                             and pp.cod_modalidad = xx.cod_modalidad
                                             and pp.cod_modulo = xx.cod_modulo)))
           or (exists (select 1
                     from ge_par_dinamicos p
                    where p.parametro in ('PRE_MAD_EXC_PYMES', 'PRE_MAD_EXCEPCION')
                      and p.cod_modalidad = s.cod_modalidad
                      and p.cod_modulo = s.cod_modulo
                      and nvl(p.val_parametro, 'N') = 'S')
               and exists
                         (select 1 -- Todos los miembros tienen solo ope de ME.
                            from sb_crc_cli_vta_cartera_tmp s
                           where s.nro_documento = p_nro_documento
                             and s.fecha= p_fecha
                             and s.nom_referencia='SALDOSV'
                             and exists (select 1  -- Ope hijas
                                           from ge_cta_dat_adicionales a
                                          where a.parametro in ('PRE_RRR_CTA_MBT','PRE_RRR_CTA_MBT1','PRE_RRR_CTA_MBT2')
                                            and a.val_parametro = pae_uti.fu_obt_valor(fus_obt_cta_operacion(s.nro_cuenta,s.cod_modulo), 1)))
           )
            );


   return v_incluir;
exception
   when no_data_found then
      return 'N';
   when others then
      return 'N';
end;
function fu_inc_ope_medidas
(
   p_nro_documento in sb_crc_vinculos_det.nro_documento%type,
   p_nro_cuenta    in ge_cta_clientes.nro_cuenta%type,
   p_fecha         in sb_crc_saldos_det.fecha%type
) return varchar2 is --FIELDESK-34615
   v_incluir     varchar2(1);

begin
   -- Incluir el prestamo de medida transitoria solo si supera la categoría del cliente,
   -- y no tiene otro tipo de operacion
   select distinct 'S'
     into v_incluir
     from sb_crc_ope_cat_cliente_tmp s
    where s.nro_documento = p_nro_documento
      and s.nro_operacion = p_nro_cuenta
      and s.fecha=p_fecha
      and (
           (exists (select  1
                     from ge_par_dinamicos p
                    where p.parametro in ('PRE_MAD_EXC_PYMES', 'PRE_MAD_EXCEPCION')
                      and p.cod_modalidad = s.cod_modalidad
                      and p.cod_modulo = s.cod_modulo
                      and nvl(p.val_parametro, 'N') = 'S') and not exists
           (select 1 -- Todos los miembros tienen solo ope de ME.
              from sb_crc_ope_cat_cliente_tmp s
             where s.nro_documento = p_nro_documento
               and S.FECHA= p_fecha
               and s.nom_referencia='SALDOS'
               and not exists (select 1
                      from ge_par_dinamicos p
                     where p.parametro in ('PRE_MAD_EXC_PYMES', 'PRE_MAD_EXCEPCION')
                       and p.cod_modalidad = s.cod_modalidad
                       and p.cod_modulo = s.cod_modulo
                       and nvl(p.val_parametro, 'N') = 'S'))) or -- No es de medida transitoria
           (not exists (select 1
                         from ge_par_dinamicos p
                        where p.parametro in ('PRE_MAD_EXC_PYMES', 'PRE_MAD_EXCEPCION')
                          and p.cod_modalidad = s.cod_modalidad
                          and p.cod_modulo = s.cod_modulo
                          and nvl(p.val_parametro, 'N') = 'S')
                 and not exists (select 1
                                   from ge_cta_dat_adicionales a
                                  where a.parametro in ('PRE_RRR_CTA_MBT','PRE_RRR_CTA_MBT1','PRE_RRR_CTA_MBT2')
                                    and a.nro_cuenta =  pae_uti.fu_obt_valor(fus_obt_cta_operacion(s.nro_operacion,s.cod_modulo), 1))) or
           (not exists (select 1
                         from ge_par_dinamicos p
                        where p.parametro in ('PRE_MAD_EXC_PYMES', 'PRE_MAD_EXCEPCION')
                          and p.cod_modalidad = s.cod_modalidad
                          and p.cod_modulo = s.cod_modulo
                          and nvl(p.val_parametro, 'N') = 'S')
                       and exists (select 1
                                 from ge_cta_dat_adicionales a
                                where a.parametro in ('PRE_RRR_CTA_MBT','PRE_RRR_CTA_MBT1','PRE_RRR_CTA_MBT2')
                                  and a.nro_cuenta = pae_uti.fu_obt_valor(fus_obt_cta_operacion(s.nro_operacion,s.cod_modulo), 1))
                       and not exists (select 1 -- Todos los miembros tienen solo ope de ME.
                               from sb_crc_ope_cat_cliente_tmp  xx
                              where xx.nro_documento = p_nro_documento
                                 and xx.fecha=p_fecha
                                 and xx.nro_operacion <> s.nro_operacion
                                 and xx.nom_referencia='SALDOS'
                                 and 'N' = (select nvl(max(pp.val_parametro), 'N')
                                            from ge_par_dinamicos pp
                                           where pp.parametro in ('PRE_MAD_EXC_PYMES', 'PRE_MAD_EXCEPCION')
                                             and pp.cod_modalidad = xx.cod_modalidad
                                             and pp.cod_modulo = xx.cod_modulo)))
           or (exists (select 1
                     from ge_par_dinamicos p
                    where p.parametro in ('PRE_MAD_EXC_PYMES', 'PRE_MAD_EXCEPCION')
                      and p.cod_modalidad = s.cod_modalidad
                      and p.cod_modulo = s.cod_modulo
                      and nvl(p.val_parametro, 'N') = 'S')
               and exists
                         (select 1 -- Todos los miembros tienen solo ope de ME.
                            from sb_crc_ope_cat_cliente_tmp s
                           where s.nro_documento = p_nro_documento
                             and s.fecha= p_fecha
                             and s.nom_referencia='SALDOS'
                             and exists (select 1  -- Ope hijas
                                           from ge_cta_dat_adicionales a
                                          where a.parametro in ('PRE_RRR_CTA_MBT','PRE_RRR_CTA_MBT1','PRE_RRR_CTA_MBT2')
                                            and a.val_parametro = pae_uti.fu_obt_valor(fus_obt_cta_operacion(s.nro_operacion,s.cod_modulo), 1)))
           )
            );


   return v_incluir;
exception
   when no_data_found then
      return 'N';
   when others then
      return 'N';
end;
procedure pr_gen_cat_codeudoria(p_fecha sb_crc_clasificaciones_det.fecha%type default null )
 is --FIELDESK-34615
  v_cat_final                   varchar2(3);
  v_cat_por_prevision           varchar2(3);
  v_por_prevision               sb_crc_clasificaciones_det.por_prevision%type;
  v_cat_distintas               varchar2(1);
  v_cat_uno_distintas           varchar2(1);
  v_cont                        number :=0;



  -- Obtiene si la cat_riesgo del cliente es distinta entre sus cuentas
  function lf_obt_cat_distintas(p_nro_documento in sb_crc_clasificaciones_det.nro_documento%type,
                                p_fecha in sb_crc_clasificaciones_det.fecha%type )
    return varchar2;
  -- Obtiene si la cat_riesgo del cliente es distinta entre sus cuentas
  function lf_obt_cat_uno_distintas(p_nro_documento in sb_crc_clasificaciones_det.nro_documento%type,
                                p_fecha in sb_crc_clasificaciones_det.fecha%type )
    return varchar2;
  -- Obtiene la categoria riesgo promedio
  function lf_obt_cat_promedio(p_nro_documento in sb_crc_clasificaciones_det.nro_documento%type,
                                p_fecha in sb_crc_clasificaciones_det.fecha%type )
    return varchar2;
  -- Obtener la categoría del clientes para categoría riesgo
  function lf_obt_cat_riesgo(p_nro_documento in sb_crc_clasificaciones_det.nro_documento%type,
                                p_fecha in sb_crc_clasificaciones_det.fecha%type )

   return varchar2;


  cursor personas is
    select a.nro_documento, a.cod_persona, a.fecha, a.cat_riesgo
      from sb_crc_clasificaciones_det a
     where a.tot_sr <> 0
      and a.fecha= p_fecha; -- Codeudoria general personas


  procedure pr_gen_datos_tmp is
    begin
    -- Creacion de tablas temporales sb_crc_cli_vta_cartera_tmp
    insert into sb_crc_cli_vta_cartera_tmp
      (select s.nom_referencia,
              s.fecha,
              s.nro_operacion,
              p.nro_cuenta,
              s.cod_modulo,
              s.cod_modalidad,
              s.tip_operacion,
              v.nro_documento,
              s.sal_capital,
              s.cla_riesgo,
              to_char(v.tip_vinculo) tip_vinculo
         from sb_Crc_saldos_Det   s,
              sb_crc_vinculos_det v,
              sb_crc_vta_carteras p
        where s.nro_operacion = v.nro_operacion
          and s.tip_operacion = v.tip_operacion
          and v.cod_modulo <> '3'
          and s.nom_referencia = 'SALDOSV'
          and v.tip_vinculo in (002, 004, 005, 006, 007, 010)
          and s.nro_operacion = p.nro_cuenta_bt
          and s.fecha = p_fecha

       union
       select sd.nom_referencia,
              sd.fecha,
              sd.nro_operacion,
              g.nro_cuenta,
              sd.cod_modulo,
              sd.cod_modalidad,
              sd.tip_operacion,
              p.nro_documento,
              sd.sal_capital,
              sd.cla_riesgo,
              '1' vip_vinculo
         from sb_Crc_saldos_Det sd, sb_crc_vta_carteras g, ba_personas p
        where g.nro_cuenta_bt = pae_uti.fu_obt_valor(fus_obt_cta_operacion(sd.nro_operacion,
                                                                           sd.cod_modulo),1)
          and g.nro_documento = p.nro_documento
          and sd.cod_modulo <> '3'
          and sd.fecha = p_fecha);

          -- Creacion de tabla temporal SB_CRC_OPE_TMP_CAT_CLIENTE
          insert into sb_crc_ope_cat_cliente_tmp
            (select s.nom_referencia,
                    s.fecha,
                    s.nro_operacion,
                    s.cod_modulo,
                    s.cod_modalidad,
                    s.tip_operacion,
                    v.nro_documento,
                    s.sal_capital,
                    s.cla_riesgo
               from sb_crc_saldos_det s, sb_crc_vinculos_det v
              where s.nro_operacion = v.nro_operacion
                and s.tip_operacion = v.tip_operacion
                and v.cod_modulo <> '3'
                and v.tip_vinculo in (002, 004, 005, 006, 007, 010)
                and s.fecha = p_fecha

             union
             select sd.nom_referencia,
                    sd.fecha,
                    sd.nro_operacion,
                    sd.cod_modulo,
                    sd.cod_modalidad,
                    sd.tip_operacion,
                    p.nro_documento,
                    sd.sal_capital,
                    sd.cla_riesgo
               from sb_crc_saldos_det  sd,
                    ge_cla_operaciones g,
                    ba_personas        p
              where g.nro_cuenta = pae_uti.fu_obt_valor(fus_obt_cta_operacion(sd.nro_operacion,
                                                                              sd.cod_modulo),1)
                and g.cod_persona = p.cod_persona
                and sd.cod_modulo <> '3'
                and sd.fecha = p_fecha);

               -- Creacion de tablas temporales SB_CRC_OPE_TMP_CODEUDORIA
      insert into sb_crc_ope_codeudoria_tmp
        (select 'A' tipo,
                a.fecha,
                a.nro_operacion,
                a.sal_capital,
                a.cla_riesgo,
                decode(a.cla_riesgo, '1a', 1.1, '1b', 1.2, a.cla_riesgo) cla_riesgo_num,
                a.nro_documento
           from sb_crc_ope_cat_cliente_tmp a
          where a.nom_referencia = 'SALDOS'
            and fu_inc_ope_medidas(a.nro_documento,
                                   a.nro_operacion,
                                   a.fecha) = 'S'
            and a.fecha = p_fecha

         union
         select 'V' tipo,
                c.fecha,
                c.nro_operacion,
                c.sal_capital,
                c.cla_riesgo,
                decode(c.cla_riesgo, '1a', 1.1, '1b', 1.2, c.cla_riesgo) cla_riesgo_num,
                d.nro_documento
           from sb_crc_saldos_det c, sb_crc_vinculos_det d
          where c.nom_referencia = 'SALDOSV'
            and c.nro_operacion = d.nro_operacion
            and d.tip_vinculo in (001, 002, 004, 005, 006, 007, 010)
            and fu_inc_ope_vta_medidas(d.nro_documento,
                                       c.nro_operacion,
                                       c.fecha) = 'S'
            and c.fecha = p_fecha
            and not exists (select 1
                   from sb_crc_ope_cat_cliente_tmp a
                  where a.nom_referencia = 'SALDOS'
                    and a.nro_documento = d.nro_documento
                    and c.fecha = a.fecha
                    and a.cod_modulo <> '3'));

      end;

  -- Obtener si la persona tiene cat_automaticas distintas entre sus  MT
  function lf_obt_cat_distintas(p_nro_documento in sb_crc_clasificaciones_det.nro_documento%type,
                                p_fecha in sb_crc_clasificaciones_det.fecha%type )
    return varchar2 is
    v_nro_documento sb_crc_clasificaciones_det.nro_documento%type;
    valor     varchar2(2);
    -- Recupera si la cuenta tiene cat_riesgo distinta entre sus cuentas
 begin
   select nro_documento,
          case
            when count(distinct cla_riesgo) >= 2 then
             'S'
            else
             'N'
          end as xx
     into v_nro_documento, valor
     from sb_crc_ope_codeudoria_tmp b
    where b.nro_documento = p_nro_documento
      and b.fecha = p_fecha
    group by b.nro_documento;

    return(valor);

  exception
    when others then
      return('N');
  end;

 function lf_obt_cat_uno_distintas(p_nro_documento in sb_crc_clasificaciones_det.nro_documento%type,
                                p_fecha in sb_crc_clasificaciones_det.fecha%type )
    return varchar2 is
    v_nro_documento sb_crc_clasificaciones_det.nro_documento%type;
    valor     varchar2(2);
  -- Recupera si la cuenta tiene cat_riesgo distinta entre sus cuentas dentro del rango del 1, 1a, 1b
 begin
   select nro_documento,
          case
            when count(distinct cla_riesgo) >= 2 and
                 max(distinct b.cla_riesgo_num) < 2 then
             'S'
            else
             'N'
          end as xx
     into v_nro_documento, valor
     from sb_crc_ope_codeudoria_tmp b
    where b.nro_documento = p_nro_documento
      and b.fecha = p_fecha
    group by b.nro_documento;

    return(valor);

  exception
    when others then
      return('N');
  end;

  -- Obtiene la cat_riesgo promedio si el cliente tiene cat_riesgo distintas
  function lf_obt_cat_promedio(p_nro_documento in sb_crc_clasificaciones_det.nro_documento%type,
                               p_fecha in sb_crc_clasificaciones_det.fecha%type)
    return varchar2 is
    p_documento sb_crc_clasificaciones_det.nro_documento%type;
    valor       varchar2(2);

      -- Recupera el promedio de la cat_riegos
      begin
       select nro_documento, round(sum(cat_pon), 0) cat_final
         into p_documento, valor
         from (select nro_documento,
                   round(((sal_capital / deuda_total) * cla_riesgo), 2) cat_pon
              from (select f.nro_documento,
                            f.nro_operacion,
                            f.cla_riesgo_num cla_riesgo,
                            f.sal_capital,
                           (select sum (b.sal_capital)
                                   from sb_crc_ope_codeudoria_tmp b
                                   where b.fecha= p_fecha
                                   and b.nro_documento= p_nro_documento) deuda_total

                      from sb_crc_ope_codeudoria_tmp f
                  where f.fecha=  p_fecha
                  and f.nro_documento = p_nro_documento ) c)
     group by nro_documento;

      if (nvl(valor,1)=1) then
        valor:= '1b';
       end if;

        return(valor);

      exception
        when others then
          return('1');
      end;

     -- Obtener la categoría de riesgo de clientes para categoría 1(uno). resolución n°37
    function lf_obt_cat_riesgo(p_nro_documento in sb_crc_clasificaciones_det.nro_documento%type,
                           p_fecha in sb_crc_clasificaciones_det.fecha%type)
        return varchar2 as
        v_categoria sb_crc_clasificaciones_det.cat_riesgo%type;
      begin

        select  max(f.cla_riesgo)
          into v_categoria
          from sb_crc_ope_codeudoria_tmp f
         where f.nro_documento = p_nro_documento
         and f.fecha =p_fecha;

          return v_categoria;
        exception
          when others then
            v_categoria := null;
            return v_categoria;
        end;

      begin
          -- Carga tabla temporal
          pr_gen_datos_tmp;
        for reg in personas Loop
          v_cat_final         := null;
          v_cat_por_prevision := null;
          v_cat_distintas     := null;
          v_por_prevision     := null;
          v_cat_uno_distintas := null;

          -- Carga variable
          v_cat_distintas := lf_obt_cat_distintas(reg.nro_documento, reg.fecha);

          if v_cat_distintas = 'S' then

            v_cat_uno_distintas := lf_obt_cat_uno_distintas(reg.nro_documento, reg.fecha);

            if v_cat_uno_distintas ='S' then
             v_cat_final := lf_obt_cat_riesgo(reg.nro_documento, reg.fecha);
            else
             v_cat_final := lf_obt_cat_promedio(reg.nro_documento, reg.fecha); --aca debe hacer la formula rara
            end if;

          else

            v_cat_final := lf_obt_cat_riesgo(reg.nro_documento, reg.fecha);

          end if;

          if v_cat_final is null then
            v_cat_final := reg.cat_riesgo;
          end if;

          v_cat_por_prevision := (case
                                     when v_cat_final = '1a' then
                                           1.1
                                     when v_cat_final = '1b' then
                                           1.2
                                     else
                                          v_cat_final

                                      end);

          v_por_prevision := fus_obt_por_prevision(v_cat_por_prevision);

         v_cont := v_cont+1;
          update it.sb_crc_clasificaciones_det a
             set a.cat_riesgo = trim(v_cat_final),
                 a.por_prevision = v_por_prevision
           where a.nro_documento = reg.nro_documento
             and a.fecha = p_fecha;

        end loop;

end;
END;
