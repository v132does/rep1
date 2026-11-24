CREATE OR REPLACE PROCEDURE it.prt_deb_aut_gp
(p_nro_cta_debito IN ta_cta_tarjetas.nro_cta_debito%TYPE DEFAULT NULL) IS

    v_estado             ge_movimientos.estado%TYPE;
    v_observacion        ta_cobros_gp.observacion%TYPE;
    v_hora               ge_movimientos.hora%TYPE := fug_ini_hora(SYSDATE, 'HH24:MI:SS');
    v_fec_actual         ge_calendarios.fec_actual%TYPE := pag_cal.fu_obt_fec_actual(5);
    v_nro_secuencia      ge_movimientos.nro_secuencia%TYPE;
    v_cod_tra_padre      ge_movimientos.cod_transaccion%TYPE := 986;
    r_gmovi              ge_movimientos%ROWTYPE;
    v_lugar              VARCHAR2(1000);
    v_mto_deu_deb        ge_cuentas.sal_contable%TYPE;
    v_mto_deu            ge_cuentas.sal_contable%TYPE;
    v_cot_mon_tar        ge_cotizaciones.val_conversion%TYPE;
    v_cot_mon_deb        ge_cotizaciones.val_conversion%TYPE;
    v_nvo_estado         ge_cuentas.estado%TYPE;
    v_sal_disponible     ge_cuentas.sal_contable%TYPE;
    v_procesa            VARCHAR2(01);
    v_cod_tra_aguinaldo  ge_transacciones.cod_transaccion%TYPE;
    v_tot_aguinaldo      NUMBER := 0;
    v_fec_ini_mes        ge_calendarios.fec_actual%TYPE;
    v_cod_ente           ah_cta_vistas.cod_ente%type := NULL;
    v_dia_aguinaldo      ge_par_dinamicos.val_parametro%TYPE := nvl(fug_obt_pardinamico('CAN_DIA_DEB_AGUINALDO'),0);
    v_fec_aguinaldo      ge_calendarios.fec_actual%TYPE;
    v_est_modulo         ba_modulos.estado%TYPE := pae_cnf.FU_OBT_EST_MODULO(5);
    v_es_nocturno        VARCHAR2(1) DEFAULT 'N';
    v_cod_procesadora    ge_par_dinamicos.val_parametro%TYPE:= fug_obt_pardinamico('COD_ENT_GLOBAL');
    v_fecha              ge_calendarios.fec_actual%TYPE := pag_cal.FU_OBT_FEC_ACTUAL(5);
    v_cod_usuario        ba_usuarios.cod_usuario%TYPE:= fug_obt_pardinamico('COD_USU_DEB_AUTOMATICO');
    v_cod_programa       ba_programas.cod_programa%TYPE:= 'PRT_DEB_AUT_GP';
    r_log                ta_logs_gp%ROWTYPE;
    v_tar_cob_no_vigentes varchar2(1) := fug_obt_pardinamico('TAR_COB_NO_VIGENTES');
    v_error               varchar2(500);
    v_err_original        varchar2(500);
--Carga los debitos automaticos a realizar
PROCEDURE lp_car_deb_automaticos IS
  BEGIN
    v_lugar:= 'Inserta Minimo al dia';
    --Cuentas con tipo pago Minimo - sin mora a debitarse en fecha de vencimiento.
    INSERT INTO ta_cobros_gp
      (nro_cta_debito,
       nro_tarjeta,
       monto,
       nro_cuenta,
       fec_proceso,
       estado,
       fec_valor,
       dia_mora,
       tipo,
       canal)
    SELECT
      cta.nro_cta_debito,
      tar.nro_tarjeta,
      nvl(cta.mto_pag_minimo,0) - nvl(cta.mto_pag_mes,0) - nvl(pag.mto_pago,0) mto_debito,
      tar.nro_cuenta,
      v_fec_actual,
      'I',
      v_fec_actual,
      nvl(cta.dia_mora,0),
      'P',
      'D'
      FROM ta_tarjetas tar,
           ge_cta_clientes cli,
           ta_cta_tarjetas cta,
           ta_sal_cierres cie,
           (select distinct
            s.cod_ent_procesadora,
            s.cod_modulo,
            s.cod_modalidad,
            s.afinidad,
            s.sub_afinidad,
            s.cod_oficina
            from IT.ta_tipos s) tip,
           ge_entes gen,
           (SELECT SUM(nvl(z.monto,0))mto_pago,
                   z.nro_cuenta
              FROM ta_cobros_gp z
             WHERE z.fec_valor = v_fec_actual
               AND z.estado IN ('C','P')
             GROUP BY z.nro_cuenta) pag
     WHERE cta.nro_cta_debito = nvl(p_nro_cta_debito, cta.nro_cta_debito)
       AND cta.nro_cta_debito IS NOT NULL
       AND tar.nro_cuenta = cli.nro_cuenta
       AND cli.cod_persona = tar.cod_persona
       AND tar.nro_cuenta = pag.nro_cuenta(+)
       AND ((tar.vigente = 'S') OR (tar.vigente = 'N' AND tar.cod_estado <> 10 AND
            v_tar_cob_no_vigentes = 'S'))
       AND cta.nro_cuenta = tar.nro_cuenta
       AND cli.relacion = 'P'
       AND cta.fec_vct_ult_cierre = v_fec_actual
       AND cta.deb_automatico = 'S'
       AND cta.tip_cobro = 'M'
       AND nvl(cta.mto_pag_minimo, 0) > 0
       AND nvl(cta.dia_mora, 0) = 0
       AND nvl(cta.mto_pag_minimo,0) - nvl(cta.mto_pag_mes,0) - nvl(pag.mto_pago,0) > 0
       AND tar.nro_cuenta = cie.nro_cuenta
       AND tip.cod_ent_procesadora = gen.cod_ente
       AND cta.cod_modulo = tip.cod_modulo
       AND cta.cod_modalidad = tip.cod_modalidad
       AND cta.afinidad     = tip.afinidad
       AND nvl(cta.sub_afinidad,'XX') = nvl(tip.sub_afinidad,'XX')
       AND (cta.cod_oficina = tip.cod_oficina OR tip.cod_oficina IS NULL)
       AND tip.cod_ent_procesadora = v_cod_procesadora
       AND nvl(cta.mto_pag_minimo,0) - nvl(pag.mto_pago,0) > 0
       AND cie.fec_cierre IN (SELECT MAX(tac.fec_cierre)
                                FROM ta_sal_cierres tac
                               WHERE tac.nro_cuenta = tar.nro_cuenta)
       --Para los casos dos principales misma cta.
       AND ((tar.fec_vencimiento = (SELECT MAX(a.fec_vencimiento)
                                      FROM ta_tarjetas a
                                     WHERE a.nro_cuenta = cta.nro_cuenta
                                       AND a.cod_persona = cli.cod_persona) AND
       --Si es una Regrabacion mantiene la fecha de vencimiento
       --Se agrega para que valide por la fecha de emision de la misma para que no de error
             tar.fec_emision = (SELECT MAX(t.fec_emision)
                                  FROM ta_tarjetas t
                                 WHERE t.nro_cuenta = cta.nro_cuenta
                                   AND t.cod_persona = cli.cod_persona)) OR
            (tar.fec_emision = (SELECT b.fec_emision
                                  FROM ta_tarjetas b
                                 WHERE b.fec_vencimiento < (SELECT MAX(c.fec_vencimiento)
                                                              FROM ta_tarjetas c
                                                             WHERE c.nro_cuenta = cta.nro_cuenta
                                                               AND c.cod_persona = cli.cod_persona)
                                   --Si la emision es la maxima y el vencimiento es menor
                                   AND b.fec_emision = (SELECT MAX(x.fec_emision)
                                                          FROM ta_tarjetas x
                                                         WHERE x.nro_cuenta = cta.nro_cuenta
                                                           AND x.cod_persona = cli.cod_persona)
                                   AND b.nro_cuenta = cta.nro_cuenta
                                   AND b.cod_persona = cli.cod_persona)));

    v_lugar:= 'Inserta Minimo en mora';
    --Cuentas con tipo pago Minimo - en mora o con saldo pendiente de pago
    INSERT INTO ta_cobros_gp
      (nro_cta_debito,
       nro_tarjeta,
       monto,
       nro_cuenta,
       fec_proceso,
       estado,
       fec_valor,
       dia_mora,
       tipo,
       canal)
    SELECT nro_cta_debito,
           tar.nro_tarjeta,
           decode(cta.fec_vct_ult_cierre, v_fec_actual, nvl(cta.mto_pag_minimo,0) -
           nvl(cta.mto_pag_mes,0) - nvl(pag.mto_pago,0), nvl(cta.mto_mora,0) -
           nvl(pag.mto_pago,0)) mto_debito,
           tar.nro_cuenta,
           v_fec_actual,
           'I',
           v_fec_actual,
           cta.dia_mora,
           'P',
           'D'
      FROM ta_tarjetas tar,
           ge_cta_clientes cli,
           ta_cta_tarjetas cta,
           ta_sal_cierres cie,
           (SELECT SUM(nvl(z.monto,0))mto_pago,
                       z.nro_cuenta
              FROM ta_cobros_gp z
             WHERE z.fec_proceso = v_fec_actual
               AND z.estado IN ('P','C')
             GROUP BY z.nro_cuenta) pag,
           (select distinct
            s.cod_ent_procesadora,
            s.cod_modulo,
            s.cod_modalidad,
            s.afinidad,
            s.sub_afinidad,
            s.cod_oficina
            from IT.ta_tipos s) tip,
           ge_entes gen
     WHERE cta.nro_cta_debito = nvl(p_nro_cta_debito, cta.nro_cta_debito)
       AND tar.nro_cuenta = cli.nro_cuenta
       AND cli.cod_persona = tar.cod_persona
       AND ((tar.vigente = 'S') OR (tar.vigente = 'N' AND tar.cod_estado <> 10 AND
            fug_obt_pardinamico('TAR_COB_NO_VIGENTES') = 'S'))
       AND cta.nro_cuenta = tar.nro_cuenta
       AND cli.relacion = 'P'
       AND cta.deb_automatico = 'S'
       AND cta.tip_cobro = 'M'
       AND cta.nro_cta_debito IS NOT NULL
       AND nvl(cta.dia_mora, 0) > 0
       AND nvl(cta.mto_mora, 0) > 0
       AND decode(cta.fec_vct_ult_cierre, v_fec_actual, nvl(cta.mto_pag_minimo,0) -
           nvl(cta.mto_pag_mes,0) - nvl(pag.mto_pago,0), nvl(cta.mto_mora,0) -
           nvl(pag.mto_pago,0)) > 0
       AND tar.nro_cuenta = pag.nro_cuenta(+)
       AND tip.cod_ent_procesadora = gen.cod_ente
       AND cta.cod_modulo = tip.cod_modulo
       AND cta.cod_modalidad = tip.cod_modalidad
       AND cta.afinidad     = tip.afinidad
       AND nvl(cta.sub_afinidad,'XX') = nvl(tip.sub_afinidad,'XX')
       AND (cta.cod_oficina = tip.cod_oficina or tip.cod_oficina IS NULL)
       AND tip.cod_ent_procesadora = v_cod_procesadora
       AND tar.nro_cuenta = cie.nro_cuenta
       AND fec_cierre IN (SELECT MAX(tac.fec_cierre)
                            FROM ta_sal_cierres tac
                           WHERE tac.nro_cuenta = tar.nro_cuenta)
         --Para los casos dos principales misma cta.
       AND ((tar.fec_vencimiento = (SELECT MAX(a.fec_vencimiento)
                                      FROM ta_tarjetas a
                                     WHERE a.nro_cuenta = cta.nro_cuenta
                                       AND a.cod_persona = cli.cod_persona) AND
          --Si es una Regrabacion mantiene la fecha de vencimiento
          --Se agrega para que valide por la fecha de emision de la misma para que no de error
             tar.fec_emision = (SELECT MAX(x.fec_emision)
                                  FROM ta_tarjetas x
                                 WHERE x.nro_cuenta = cta.nro_cuenta
                                   AND x.cod_persona = cli.cod_persona)) OR
            (tar.fec_emision = (SELECT b.fec_emision
                                  FROM ta_tarjetas b
                                 WHERE b.fec_vencimiento < (SELECT MAX(c.fec_vencimiento)
                                                              FROM ta_tarjetas c
                                                             WHERE c.nro_cuenta = cta.nro_cuenta
                                                               AND c.cod_persona = cli.cod_persona)
            --Si la emision es la maxima y el vencimiento es menor
                                 AND b.fec_emision = (SELECT MAX(x.fec_emision)
                                                        FROM ta_tarjetas x
                                                       WHERE x.nro_cuenta = cta.nro_cuenta
                                                         AND x.cod_persona = cli.cod_persona)
                                                         AND b.nro_cuenta = cta.nro_cuenta
                                                         AND b.cod_persona = cli.cod_persona)));

    v_lugar:= 'Inserta Total';
    --Cuentas con tipo de pago Total, pendiente de pago.
    INSERT INTO ta_cobros_gp
        (nro_cta_debito,
         nro_tarjeta,
         monto,
         nro_cuenta,
         fec_proceso,
         estado,
         fec_valor,
         dia_mora,
         tipo,
         canal)
      SELECT
        cta.nro_cta_debito,
        tar.nro_tarjeta,
        nvl(mto.mto_deuda,0) - nvl(pag.mto_pago,0) mto_debito,
        tar.nro_cuenta,
        v_fec_actual,
        'I',
        v_fec_actual,
        nvl(cta.dia_mora,0),
        'P',
        'D'
        FROM ta_tarjetas tar,
             ge_cta_clientes cli,
             ta_cta_tarjetas cta,
             ta_sal_cierres cie,
             (select distinct
              s.cod_ent_procesadora,
              s.cod_modulo,
              s.cod_modalidad,
              s.afinidad,
              s.sub_afinidad,
              s.cod_oficina
              from IT.ta_tipos s) tip,
             ge_entes gen,
             (SELECT SUM(nvl(z.monto,0))mto_pago,
                     z.nro_cuenta
                FROM ta_cobros_gp z
               WHERE z.fec_valor > (SELECT MAX(a.fec_cierre)
                                      FROM ta_sal_cierres a
                                     WHERE a.nro_cuenta = z.nro_cuenta
                                       AND a.fec_vto_pago <= v_fec_actual)
                 AND z.estado IN ('C','P')
               GROUP BY z.nro_cuenta) pag,
             --El mayor registro de ta sal cierres donde la fecha de vencimiento sea menor a la fecha del diaÂ (casosÂ enÂ mora)
             (SELECT ci.sal_financiado mto_deuda, ci.nro_cuenta
                FROM ta_sal_cierres ci
               WHERE ci.fec_cierre = (SELECT MAX(a.fec_cierre)
                                        FROM ta_sal_cierres a
                                       WHERE a.nro_cuenta = ci.nro_cuenta
                                         AND a.fec_vto_pago <= v_fec_actual)) mto
       WHERE cta.nro_cta_debito = nvl(p_nro_cta_debito, cta.nro_cta_debito)
         AND cta.nro_cta_debito IS NOT NULL
         AND tar.nro_cuenta = cli.nro_cuenta
         AND cli.cod_persona = tar.cod_persona
         AND tar.nro_cuenta = pag.nro_cuenta(+)
         AND cta.nro_cuenta = mto.nro_cuenta
         AND ((tar.vigente = 'S') OR (tar.vigente = 'N' AND tar.cod_estado <> 10 AND
             fug_obt_pardinamico('TAR_COB_NO_VIGENTES') = 'S'))
         AND cta.nro_cuenta = tar.nro_cuenta
         AND cli.relacion = 'P'
         AND cta.deb_automatico = 'S'
         AND cta.tip_cobro = 'T'
         AND tar.nro_cuenta = cie.nro_cuenta
         AND tip.cod_ent_procesadora = gen.cod_ente
         AND cta.cod_modulo = tip.cod_modulo
         AND cta.cod_modalidad = tip.cod_modalidad
         AND cta.afinidad     = tip.afinidad
         AND nvl(cta.sub_afinidad,'XX') = nvl(tip.sub_afinidad,'XX')
         AND (cta.cod_oficina = tip.cod_oficina OR tip.cod_oficina IS NULL)
         AND tip.cod_ent_procesadora = v_cod_procesadora
         AND nvl(mto.mto_deuda,0) > 0
         AND nvl(mto.mto_deuda,0) - nvl(pag.mto_pago,0) > 0
         AND cie.fec_cierre IN (SELECT MAX(tac.fec_cierre)
                                  FROM ta_sal_cierres tac
                                 WHERE tac.nro_cuenta = tar.nro_cuenta)
         --Para los casos dos principales misma cta.
         AND ((tar.fec_vencimiento = (SELECT MAX(a.fec_vencimiento)
                                        FROM ta_tarjetas a
                                       WHERE a.nro_cuenta = cta.nro_cuenta
                                         AND a.cod_persona = cli.cod_persona) AND
         --Si es una Regrabacion mantiene la fecha de vencimiento
         --Se agrega para que valide por la fecha de emision de la misma para que no de error
               tar.fec_emision = (SELECT MAX(t.fec_emision)
                                    FROM ta_tarjetas t
                                   WHERE t.nro_cuenta = cta.nro_cuenta
                                     AND t.cod_persona = cli.cod_persona)) OR
              (tar.fec_emision = (SELECT b.fec_emision
                                    FROM ta_tarjetas b
                                   WHERE b.fec_vencimiento < (SELECT MAX(c.fec_vencimiento)
                                                                FROM ta_tarjetas c
                                                               WHERE c.nro_cuenta = cta.nro_cuenta
                                                                 AND c.cod_persona = cli.cod_persona)
                                     --Si la emision es la maxima y el vencimiento es menor
                                     AND b.fec_emision = (SELECT MAX(x.fec_emision)
                                                            FROM ta_tarjetas x
                                                           WHERE x.nro_cuenta = cta.nro_cuenta
                                                             AND x.cod_persona = cli.cod_persona)
                                     AND b.nro_cuenta = cta.nro_cuenta
                                     AND b.cod_persona = cli.cod_persona)));
  EXCEPTION
    WHEN OTHERS THEN
      r_log.comentario := substr('Error en proceso : ' || r_log.nom_proceso || ' - '||
                          v_lugar || ' - ' ||
                          to_char(v_fec_actual, 'dd/mm/yyyy') || ' - ' ||
                          SQLERRM,1,499);
      pat_igp.pr_ins_log(r_log);
      raise_application_error(-20000, 'Error al insertar cuentas a debitar. '||SQLERRM);
END;

PROCEDURE lp_obt_mto_aguinaldo(p_nro_cta       VARCHAR2,
                               p_mto_aguinaldo OUT NUMBER,
                               p_fec_aguinaldo OUT DATE) IS
  BEGIN
    SELECT SUM(a.monto), max(a.fecha)
      INTO p_mto_aguinaldo, p_fec_aguinaldo
      FROM gv_movimientos a
     WHERE a.fecha >= v_fec_ini_mes
       AND a.fecha <= v_fec_actual
       AND a.cod_tra_padre = v_cod_tra_aguinaldo
       AND a.cod_transaccion = 602
       AND a.nro_cuenta = p_nro_cta
       AND a.reversado = 'N';
  EXCEPTION
    WHEN OTHERS THEN
      p_mto_aguinaldo:=0;
      p_fec_aguinaldo:=null;
    END;

PROCEDURE pr_ver_horario(p_fec_proceso IN DATE,
                         p_hor_proceso IN VARCHAR2,
                         p_es_nocturno OUT VARCHAR2,
                         p_fecha       OUT DATE) IS
  v_es_nocturno VARCHAR2(1) := 'N';
  v_fec_proceso ge_movimientos.fecha%TYPE;
  v_est_modulo  ba_modulos.estado%TYPE := pae_cnf.FU_OBT_EST_MODULO(5);
  v_hor_limite  VARCHAR2(8) := '999999';
  v_cod_ofi_origen ge_cta_clientes.cod_oficina%TYPE;

  BEGIN
  -- Obtiene la oficina de Casa Matriz.
    BEGIN
      SELECT cod_ofi_matriz
        INTO v_cod_ofi_origen
        FROM ge_par_generales;
    END;

    v_es_nocturno := 'N'; -- Para grabar en las tablas nocturnas
    v_fec_proceso := pag_cal.fu_obt_fec_actual(5);
    p_fecha := v_fec_proceso;
    IF v_est_modulo = 2 THEN
      -- El modulo esta abierto
      -- Verifica la hora --
      IF (p_hor_proceso > v_hor_limite AND v_fec_proceso = p_fec_proceso) OR
        v_fec_proceso < p_fec_proceso THEN
          v_fec_proceso := pag_cal.fu_obt_fec_habil(v_fec_proceso + 1,
                                                    1,
                                                    v_cod_ofi_origen);
        p_fecha := v_fec_proceso;
        v_es_nocturno := 'N'; -- Para grabar en las tablas nocturnas
      END IF;
    ELSE
      v_fec_proceso := pag_cal.fu_obt_fec_habil(v_fec_proceso + 1,
                                                1,
                                                v_cod_ofi_origen);
      p_fecha := v_fec_proceso;
      v_es_nocturno := 'S'; -- Para grabar en las tablas nocturnas
    END IF;
    p_es_nocturno := v_es_nocturno;
  END;

FUNCTION fu_obt_hor_disponible(p_fecha       IN DATE,
                               p_hora        IN VARCHAR2,
                               p_cod_usuario IN VARCHAR2,
                               p_es_nocturno IN VARCHAR2) RETURN VARCHAR2 IS
  v_existe VARCHAR2(1);
  v_hora   VARCHAR2(8) := p_hora;
  c        NUMBER(10)  :=0;
BEGIN
  v_hora := pag_gen.FU_OBT_SIG_SEGUNDO(v_hora);
  IF p_es_nocturno = 'N' THEN
    LOOP
      c:=c+1;
      BEGIN
        SELECT 'S'
          INTO v_existe
          FROM ge_movimientos
         WHERE fecha = p_fecha
           AND hora = v_hora
           AND cod_usuario = p_cod_usuario
           AND rownum <= 1;
      EXCEPTION
        WHEN no_data_found THEN
          v_existe := 'N';
      END;
      EXIT WHEN v_existe = 'N' OR c=86400;
      IF c<>86400 THEN
        v_hora := pag_gen.fu_obt_sig_segundo(v_hora);
      END IF;
    END LOOP;
    IF c<>86400 THEN
      RETURN v_hora;
    ELSE
      RETURN '999';--error
    END IF;
      RETURN v_hora;
  ELSE -- es nocturno
    LOOP
      BEGIN
        SELECT 'S'
          INTO v_existe
          FROM ge_movimientos_noc
         WHERE fecha = p_fecha
           AND hora = v_hora
           AND cod_usuario = p_cod_usuario
           AND rownum <= 1;
      EXCEPTION
        WHEN no_data_found THEN
          v_existe := 'N';
      END;
      EXIT WHEN v_existe = 'N' OR c=86400;
      IF c<>86400 THEN
        v_hora := pag_gen.fu_obt_sig_segundo(v_hora);
      END IF;
    END LOOP;
    IF c<>86400 THEN
      RETURN v_hora;
    ELSE
      RETURN '999';--error
    END IF;
  END IF;
END;

PROCEDURE lp_pro_debitos IS
    CURSOR op_cursor IS
    SELECT cob.nro_cta_debito,
           cob.nro_tarjeta,
           cob.monto,
           cta.cod_modulo,
           cta.cod_moneda,
           cta.cod_modalidad,
           cta.nro_cuenta,
           cta.cod_oficina,
           pag_cta.fu_ver_tra_prohibida(cta.nro_cuenta, 986) tra_prohibida,
           cob.ROWID fila
      FROM ta_cta_tarjetas cta
      JOIN ta_tarjetas tar ON cta.nro_cuenta = tar.nro_cuenta
      JOIN ta_cobros_gp cob ON cob.nro_tarjeta = tar.nro_tarjeta AND cob.nro_cuenta = cta.nro_cuenta
     WHERE cob.nro_cta_debito = NVL(p_nro_cta_debito, cob.nro_cta_debito)
       AND cob.fec_proceso >= v_fec_actual
       AND cob.estado = 'I';
    TYPE t_op_tab IS TABLE OF op_cursor%ROWTYPE;
    v_op_tab t_op_tab;

    TYPE t_update IS RECORD (   fila         ROWID,
                            nro_cuenta   ta_cobros_gp.nro_cuenta%TYPE,
                            estado       ta_cobros_gp.estado%TYPE,
                            monto        ta_cobros_gp.monto%TYPE,
                            observacion  ta_cobros_gp.observacion%TYPE,
                            fec_proceso  ta_cobros_gp.fec_proceso%TYPE,
                            fec_valor    ta_cobros_gp.fec_valor%TYPE,
                            cod_usuario  ta_cobros_gp.cod_usuario%TYPE,
                            hora         ta_cobros_gp.hora%TYPE);
    TYPE t_update_tab IS TABLE OF t_update INDEX BY PLS_INTEGER;
    v_update_tab t_update_tab;
    j number;
    v_lote number:= fug_obt_pardinamico('GP_LOTE');
    v_limite_bc number:= fug_obt_pardinamico('GP_LIMITE_BC');
    v_contador number:=0;
    v_contador_bc number:=0;        
BEGIN
    j := 0;
    pag_cal.PR_OBT_DAT_CALENDAR(5);
    v_fec_ini_mes       := pag_cal.G_PRI_DIA_MES;

    OPEN op_cursor;
    LOOP
        FETCH op_cursor BULK COLLECT INTO v_op_tab limit v_limite_bc;
        EXIT WHEN v_op_tab.COUNT = 0;
        v_contador_bc := v_op_tab.count;
        FOR i IN 1 .. v_op_tab.COUNT LOOP
            v_lugar        := 'Tarjeta  : ' || v_op_tab(i).nro_tarjeta;
            v_estado       := 'P';
            v_observacion  := 'Registro procesado';
            --Recupera datos de la cuenta de debito
            pag_cta.pr_obt_cuenta(v_op_tab(i).nro_cta_debito);
            IF pag_cta.g_cod_error <> 0 THEN
                v_estado       := 'E';
                v_observacion  := fug_obt_err_sueldos(pag_cta.g_cod_error);
            END IF;
            -- Calcula el total a debitar en la moneda de la cuenta de debito
            v_cot_mon_tar := NULL;
            v_cot_mon_deb := NULL;
            v_mto_deu_deb := 0;
            v_mto_deu     := v_op_tab(i).monto;
            v_mto_deu_deb := v_mto_deu;
            v_cod_ente    := pag_cta.g_ctas.cod_ente;
        
            IF v_cod_ente IS NOT NULL THEN
                v_cod_tra_aguinaldo := fug_obt_parentes(v_cod_ente, 'COD_TRA_PAD_AGUINALDO');
                IF v_cod_tra_aguinaldo is not null then
                    lp_obt_mto_aguinaldo(v_op_tab(i).nro_cta_debito, v_tot_aguinaldo, v_fec_aguinaldo);
                END IF;
            END IF;
         
            IF NVL(v_op_tab(i).tra_prohibida, 'N') = 'S' THEN
                v_estado := 'E';
                v_observacion  := 'Cuenta de Tarjeta con Transaccion Prohibida';
            END IF;

            IF v_op_tab(i).cod_moneda != pag_cta.g_ctas.cod_moneda THEN
                v_estado       := 'E';
                v_observacion  := 'Cobro en diferentes monedas no permitido';
            END IF;

            IF nvl(pag_cta.g_ctas.sal_disponible, 0) < nvl(v_mto_deu_deb, 0) AND
            nvl(pag_cta.g_ctas.sal_disponible, 0) > 0 THEN
                v_mto_deu_deb := nvl(pag_cta.g_ctas.sal_disponible, 0);
                v_mto_deu := v_mto_deu_deb;
            END IF;
            IF v_cod_ente IS NOT NULL AND ((v_fec_actual - v_fec_aguinaldo) <= v_dia_aguinaldo) THEN
                IF nvl(pag_cta.g_ctas.sal_disponible,0) - nvl(v_tot_aguinaldo,0) > 0 THEN
                    IF nvl(pag_cta.g_ctas.sal_disponible,0) - nvl(v_tot_aguinaldo,0) < (nvl(v_mto_deu_deb,0)) THEN
                        v_mto_deu_deb := nvl(pag_cta.g_ctas.sal_disponible,0) - nvl(v_tot_aguinaldo,0);
                        v_mto_deu     := v_mto_deu_deb;
                    END IF;
                ELSE
                    v_estado := 'E';
                    v_observacion  := 'Saldo no cubre la deuda.';
                END IF;
            END IF;

            SAVEPOINT mov_credito;
            IF v_estado = 'P' THEN
                v_hora   := pag_gen.fu_obt_sig_segundo(v_hora);
                pr_ver_horario(v_fecha,v_hora,v_es_nocturno,v_fecha);
                v_hora   := fu_obt_hor_disponible(v_fecha,v_hora,v_cod_usuario,v_es_nocturno);
                IF v_hora='999' THEN
                    it.prg_obt_usu_hor_disponible(v_fecha,v_hora,v_cod_usuario,v_es_nocturno);
                END IF;
                v_lugar := 'Inserta mov. credito ' || v_op_tab(i).nro_cuenta;
                --Genera el movimiento por el credito
                r_gmovi.cod_usuario     := v_cod_usuario;
                r_gmovi.hora            := v_hora;
                r_gmovi.fecha           := v_fec_actual;
                v_nro_secuencia         := 1;
                r_gmovi.nro_secuencia   := v_nro_secuencia;
                r_gmovi.cod_modulo      := v_op_tab(i).cod_modulo;
                r_gmovi.cod_modalidad   := v_op_tab(i).cod_modalidad;
                r_gmovi.cod_oficina     := v_op_tab(i).cod_oficina;
                r_gmovi.cod_moneda      := v_op_tab(i).cod_moneda;
                r_gmovi.fec_valor       := v_fec_actual;
                r_gmovi.cod_tra_padre   := v_cod_tra_padre;
                r_gmovi.cod_mod_padre   := 5;
                r_gmovi.cod_mad_padre   := v_op_tab(i).cod_modalidad;
                r_gmovi.cod_transaccion := 978;
                r_gmovi.monto           := v_mto_deu;
                r_gmovi.nro_documento   := v_op_tab(i).nro_cuenta;
                r_gmovi.nro_cuenta      := v_op_tab(i).nro_cuenta;
                r_gmovi.cod_ofi_origen  := v_op_tab(i).cod_oficina;
                r_gmovi.emi_aviso       := 'N';
                r_gmovi.concepto        := 'Credito de tarjetas';
                r_gmovi.estado          := 'N';
                r_gmovi.reversado       := 'N';
                BEGIN
                    pag_gen.pr_ins_ge_movimiento(r_gmovi);
                EXCEPTION
                WHEN OTHERS THEN
                    BEGIN
                        pr_ver_horario(v_fecha,v_hora,v_es_nocturno,v_fecha);
                        prg_obt_usu_hor_disponible(v_fecha,v_hora,v_cod_usuario,v_es_nocturno);
                        r_gmovi.hora  := v_hora;
                        pag_gen.pr_ins_ge_movimiento(r_gmovi,v_es_nocturno);
                    EXCEPTION
                    WHEN OTHERS THEN
                        BEGIN
                            v_hora       := fu_obt_hor_disponible(v_fecha,v_hora,v_cod_usuario,v_es_nocturno);
                            r_gmovi.hora := v_hora;
                            pag_gen.pr_ins_ge_movimiento(r_gmovi,v_es_nocturno);
                        EXCEPTION
                            WHEN OTHERS THEN
                            v_estado         := 'E';
                            v_observacion    := 'Error al insertar mov. credito';
                            r_log.comentario := substr('Error en proceso : ' || r_log.nom_proceso || ' - '||
                            v_lugar || ' - ' ||
                            to_char(v_fec_actual, 'dd/mm/yyyy') || ' - ' ||
                            SQLERRM,1,499);
                            pat_igp.pr_ins_log(r_log);
                        END;
                    END;
                END;
            END IF;

            IF v_estado = 'P' THEN
                -- Verificar si puede realizarse la operación sobre la cuenta de debito
                pag_cta.pr_ver_operacion(v_op_tab(i).nro_cta_debito,
                v_cod_tra_padre,
                v_op_tab(i).cod_modulo,
                v_op_tab(i).cod_modalidad,
                'D',
                pag_cta.g_ctas.cod_moneda,
                v_mto_deu_deb,
                v_op_tab(i).cod_oficina,
                -- out
                pag_cta.g_ctas.cod_modulo,
                pag_cta.g_ctas.cod_modalidad,
                v_nvo_estado,
                v_sal_disponible,
                v_procesa);
                IF pag_cta.g_cod_error <> 0 OR v_procesa = 'N' THEN
                    v_estado      := 'E';
                    v_observacion := substr(fug_obt_err_sueldos(pag_cta.g_cod_error), 1, 50);
                    ROLLBACK TO mov_credito;
                END IF;
                IF v_estado = 'P' THEN
                    -- Debitar de la cuenta
                    v_lugar:= 'Debito en la cuenta ' || v_op_tab(i).nro_cta_debito;
                    BEGIN
                        pag_cta.pr_set_variables(v_cod_usuario,
                        NULL,
                        NULL,
                        'N',
                        'N',
                        v_nro_secuencia,
                        NULL,
                        NULL,
                        NULL,
                        NULL);
                        pag_cta.pr_act_operacion(v_op_tab(i).nro_cta_debito,
                        v_hora,
                        'D',
                        pag_cta.g_ctas.cod_moneda,
                        v_mto_deu_deb,
                        v_cod_tra_padre,
                        503,
                        v_op_tab(i).nro_cuenta,
                        v_cot_mon_deb,
                        v_op_tab(i).cod_oficina,
                        v_op_tab(i).cod_modulo,
                        v_op_tab(i).cod_modalidad,
                        NULL,
                        NULL,
                        'Debito automatico de tarjetas ',
                        'S',
                        v_nro_secuencia,
                        v_fec_actual,
                        NULL,
                        NULL,
                        v_mto_deu);
                        IF pag_cta.g_cod_error <> 0 THEN
                            v_estado := 'E';
                            v_observacion  := substr(fug_obt_err_sueldos(pag_cta.g_cod_error), 1, 50);
                            ROLLBACK TO mov_credito;
                        END IF;
                    EXCEPTION
                        WHEN OTHERS THEN
                        v_estado := 'E';
                        v_observacion := 'Error al procesar mov. debito';
                        ROLLBACK TO mov_credito;
                        r_log.comentario := substr('Error en proceso : ' || r_log.nom_proceso || ' - ' ||
                        v_lugar || ' - ' ||
                        to_char(v_fec_actual, 'dd/mm/yyyy') || ' - ' ||
                        SQLERRM,1,499);
                        pat_igp.pr_ins_log(r_log);
                    END;
                END IF;
            END IF;

            -- Se actualiza el registro segun resultados --
            BEGIN
                v_lugar := 'Preparando actualización cta. ' || v_op_tab(i).nro_cuenta;
                j := j + 1;
                v_update_tab(j).fila        := v_op_tab(i).fila;
                v_update_tab(j).nro_cuenta  := v_op_tab(i).nro_cuenta;
                v_update_tab(j).estado      := v_estado;
                v_update_tab(j).monto       := v_mto_deu;
                v_update_tab(j).observacion := v_observacion;
                v_update_tab(j).fec_proceso := v_fec_actual;
                v_update_tab(j).fec_valor   := v_fec_actual;
                v_update_tab(j).cod_usuario := r_gmovi.cod_usuario;
                v_update_tab(j).hora        := r_gmovi.hora;
            EXCEPTION
                WHEN OTHERS THEN
                r_log.comentario := substr('Error en proceso : ' || r_log.nom_proceso || ' - '||
                v_lugar || ' - ' ||
                to_char(v_fec_actual, 'dd/mm/yyyy') || ' - ' ||
                SQLERRM,1,499);
                pat_igp.pr_ins_log(r_log);
            END;
            -- Incrementar el contador
            v_contador := v_contador + 1;      
            -- Julio Leguizamon: Hacer commit cada vez que se alcanza el tamaño del lote o cuando el contador es igual al tamaño del BULK COLLECT
            IF MOD(v_contador, v_lote) = 0 OR v_contador = v_contador_bc THEN                       
                -- Se actualiza el registro segun resultados --
                BEGIN
                    FORALL i IN v_update_tab.FIRST .. v_update_tab.LAST SAVE EXCEPTIONS
                    UPDATE ta_cobros_gp
                    SET estado      = v_update_tab(i).estado,
                    monto       = v_update_tab(i).monto,
                    observacion = v_update_tab(i).observacion,
                    fec_proceso = v_update_tab(i).fec_proceso,
                    fec_valor   = NVL(fec_valor, v_update_tab(i).fec_valor),
                    cod_usuario = v_update_tab(i).cod_usuario,
                    hora        = v_update_tab(i).hora
                    WHERE ROWID = v_update_tab(i).fila;

                    -- Registrar errores de fila
                    FOR k IN 1 .. SQL%BULK_EXCEPTIONS.COUNT LOOP
                        DECLARE
                        v_idx PLS_INTEGER := SQL%BULK_EXCEPTIONS(k).ERROR_INDEX;
                        BEGIN
                            IF v_update_tab.EXISTS(v_idx) THEN
                                r_log.comentario := substr(
                                'Error en actualización masiva: fila ' || v_idx ||
                                ', nro_cuenta: ' || v_update_tab(v_idx).nro_cuenta ||
                                ' - ' || SQLERRM(-SQL%BULK_EXCEPTIONS(k).ERROR_CODE), 1, 499);
                                pat_igp.pr_ins_log(r_log);
                            END IF;
                        END;
                        r_log.comentario := substr('Error en actualización masiva: fila ' || k ||
                        ', nro_cuenta: ' || v_update_tab(k).nro_cuenta ||
                        ' - ' || SQLERRM(-SQL%BULK_EXCEPTIONS(k).ERROR_CODE), 1, 499);
                        pat_igp.pr_ins_log(r_log);
                    END LOOP;
                EXCEPTION
                WHEN OTHERS THEN
                NULL;
                END;
                commit;
            End if;            
        END LOOP;
        -- inicializar antes de que cargue el siguiente lote
        j := 0;
        v_contador := 0;
    END LOOP;
    CLOSE op_cursor;
END;

BEGIN
  BEGIN
    pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1;
  END;
  r_log.nom_proceso := v_cod_programa;

  IF p_nro_cta_debito IS NULL THEN
    r_log.fec_hor_ini    := SYSDATE;
    r_log.comentario     := '*** Inicio de proceso de Debito Automatico de TCs***';
    pat_igp.pr_ins_log(r_log, FALSE);
  END IF;
   --Desabilitar lo trigger de ta_cobros_gp
  sql_util.ejecute_dml('alter trigger ta_ta_cobros_gp disable', v_error);
  IF v_error IS NOT NULL THEN
      raise_application_error(-20000, 'Al deshabilitar triggers ' || v_error);
   END IF;
  --Carga los debitos a cobrar
  lp_car_deb_automaticos;
  --Proceso de debitos automaticos
  lp_pro_debitos;
  IF p_nro_cta_debito IS NULL THEN
    r_log.fec_hor_ini    := SYSDATE;
    r_log.comentario     := '*** Fin de proceso de Debito Automatico de TCs***';
    pat_igp.pr_ins_log(r_log, FALSE);
  END IF;
    --Habilitar lo trigger de ta_cobros_gp
     sql_util.ejecute_dml('alter trigger ta_ta_cobros_gp enable', v_error);
    IF v_error IS NOT NULL THEN
      raise_application_error(-20000, 'Al habilitar triggers ' || v_error);
   END IF;
EXCEPTION
  WHEN OTHERS THEN
    v_err_original := sqlerrm;
      --Habilitar lo trigger de ta_cobros_gp en caso de error en el proceso
      sql_util.ejecute_dml('alter trigger ta_ta_cobros_gp enable', v_error);
      IF v_error IS NOT NULL THEN
         v_lugar := v_lugar|| ' y ocurrio un error al habilitar triggers en raise final '||v_error;
      END IF;
    r_log.comentario :=  substr('Error en proceso : ' || r_log.nom_proceso || ' - '||
                         v_lugar || ' ' ||
                         to_char(v_fec_actual, 'dd/mm/yyyy') || ' - ' ||
                         v_err_original,1,499);
    pat_igp.pr_ins_log(r_log);
    raise_application_error(-20000, 'Error : ' || v_lugar || ' ' || v_err_original);
END;
/
