CREATE OR REPLACE PACKAGE BODY IT.PAS_BCP IS
   v_dias_capital number:=0;
   v_dias_interes VARCHAR2(4000);
   v_auxiliar1 CLOB;

  /* Permite generar las tablas de encajes legales. */
  /* Procedimiento en desuso, se utiliza los procedimientos PR_GEN_ENC_MENSUAL y PR_GEN_REP_ENC_MENSUAL */
  PROCEDURE PR_GEN_ENCAJES IS


    p_fec_actual DATE;
    v_cod_mon_local ge_par_generales.cod_mon_local%TYPE := pag_gen.FU_OBT_MON_LOCAL;

    /* Calcula el encaje legal para moneda local */
    PROCEDURE lp_cal_enc_mon_local(p_fec_actual IN DATE);
    /* Calcular encaje legal moneda extranjera */
    PROCEDURE lp_cal_enc_mon_extr(p_fec_actual IN DATE);
    /* Calcular el encaje especial */
    PROCEDURE lp_cal_enc_especial(p_fec_actual IN DATE);
    rv_gcale    ge_calendarios%ROWTYPE;
    nv_cantidad NUMBER(03);

    /* Calcula el encaje legal para moneda local */
    PROCEDURE lp_cal_enc_mon_local(p_fec_actual IN DATE) IS

      v_sal_actual         sb_encajes_ml.sal_actual%TYPE;
      v_sal_actual1        sb_encajes_ml.sal_actual%TYPE;
      v_sal_actual2        sb_encajes_ml.sal_actual%TYPE;
      v_sujeto_d           sb_encajes_ml.sujeto_d%TYPE;
      v_sujeto_e           sb_encajes_ml.sujeto_e%TYPE;
      v_mto_remunerar      sb_encajes_ml.mto_remunerar%TYPE;
      v_tot_exigido        sb_encajes_ml.tot_exigido%TYPE;
      v_sujeto_f           sb_encajes_ml.sujeto_f%TYPE;
      v_sujeto_g           sb_encajes_ml.sujeto_g%TYPE;
      v_encaje_h           sb_encajes_ml.encaje_h%TYPE;
      v_encaje_i           sb_encajes_ml.encaje_i%TYPE;
      v_encaje_j           sb_encajes_ml.encaje_j%TYPE;
      v_sal_actual3        sb_encajes_ml.sal_actual%type;
      v_sal_actual3a       sb_encajes_ml.sal_actual%type;
      v_sal_actual3b       sb_encajes_ml.sal_actual%type;
      v_sal_actual3c       sb_encajes_ml.sal_actual%type;
      v_cod_rub_dep_encaje varchar2(15);
      v_bcp_depositado     number(18, 2);

    BEGIN
      -- Para < 2 dias
      SELECT round(nvl(SUM(capital - nvl(sal_ret_batch, 0)), 0), 0)
        INTO v_sal_actual
        FROM ah_cta_certificados ah
       WHERE fec_vencimiento - fec_apertura < 2
         AND est_batch NOT IN ('T', 'A', 'C', 'X')
         AND est_cer_batch NOT IN ('V', 'P')
         AND nvl(ah.sal_ret_batch, 0) = 0
         AND cod_moneda = v_cod_mon_local;
      --CDAs
      SELECT round(nvl(SUM(decode(ah.est_cer_batch,
                                  'V',
                                  ah.sal_tot_batch,
                                  'P',
                                  ah.sal_tot_batch,
                                  ah.sal_tot_batch - ah.capital)),
                       0),
                   0)
        INTO v_sal_actual2
        FROM ah_cta_certificados ah
       WHERE est_batch NOT IN ('T', 'A', 'C', 'X')
         AND (est_cer_batch IN ('V', 'P') OR sal_tot_batch > capital)
         AND nvl(ah.sal_ret_batch, 0) = 0
         AND cod_moneda = v_cod_mon_local;

      SELECT round(nvl(SUM(sal_tot_batch - nvl(sal_ret_batch, 0)), 0), 0) --BRIOS
        INTO v_sal_actual1
        FROM ah_cta_vistas ah
       WHERE cod_moneda = v_cod_mon_local
         AND est_batch NOT IN ('A', 'C'); --Abierta y cancelada

      --CUENTAS CORRIENTES
      --Disponible = Total - Retenido - Bloqueado

      --Disponible > 0 y Bloqueado = 0
      --Encaje = Disponible
      SELECT round(sum(nvl(cc.sal_tot_batch, 0) - nvl(cc.sal_ret_batch, 0) -
                       nvl(cc.sal_blo_batch, 0)),
                   0)
        INTO V_SAL_ACTUAL3A
        FROM cc_cta_corrientes cc
       WHERE cod_moneda = v_cod_mon_local
            --and est_batch not in ('X','A','C')
         AND (NVL(cc.SAL_TOT_BATCH, 0) <> 0 OR
             NVL(cc.SAL_RET_BATCH, 0) <> 0 OR
             NVL(cc.SAL_BLO_BATCH, 0) <> 0)
         AND (nvl(cc.sal_tot_batch, 0) - nvl(cc.sal_ret_batch, 0) -
             nvl(cc.sal_blo_batch, 0)) > 0
         AND nvl(cc.sal_blo_batch, 0) = 0;

      --Disponible > 0 y Bloqueado > 0
      --Encaje = Disponible + Bloqueado
      SELECT round(sum(nvl(cc.sal_tot_batch, 0) - nvl(cc.sal_ret_batch, 0)),
                   0)
        INTO V_SAL_ACTUAL3B
        FROM cc_cta_corrientes cc
       WHERE cod_moneda = v_cod_mon_local
            --and est_batch not in ('X','A','C')
         AND (NVL(cc.SAL_TOT_BATCH, 0) <> 0 OR
             NVL(cc.SAL_RET_BATCH, 0) <> 0 OR
             NVL(cc.SAL_BLO_BATCH, 0) <> 0)
         AND (nvl(cc.sal_tot_batch, 0) - nvl(cc.sal_ret_batch, 0) -
             nvl(cc.sal_blo_batch, 0)) > 0
         AND nvl(cc.sal_blo_batch, 0) > 0;

      --Disponible <= 0 y Bloqueado > 0
      --Encaje = Bloqueado
      SELECT round(sum(nvl(cc.sal_blo_batch, 0)), 0)
        INTO V_SAL_ACTUAL3C
        FROM cc_cta_corrientes cc
       WHERE cod_moneda = v_cod_mon_local
            --and est_batch not in ('X','A','C')
         AND (NVL(cc.SAL_TOT_BATCH, 0) <> 0 OR
             NVL(cc.SAL_RET_BATCH, 0) <> 0 OR
             NVL(cc.SAL_BLO_BATCH, 0) <> 0)
         AND (nvl(cc.sal_tot_batch, 0) - nvl(cc.sal_ret_batch, 0) -
             nvl(cc.sal_blo_batch, 0)) <= 0
         AND nvl(cc.sal_blo_batch, 0) > 0;

      --Saldo total para cuentas corrientes
      V_SAL_ACTUAL3 := nvl(V_SAL_ACTUAL3A, 0) + nvl(V_SAL_ACTUAL3B, 0) + nvl(V_SAL_ACTUAL3C, 0);

      v_sal_actual := v_sal_actual + v_sal_actual1 + v_sal_actual2 + V_SAL_ACTUAL3;
      v_sujeto_d   := v_sal_actual; --pues no se tienen saldos a julio 1996

      -- De 2 a 360 dias
      SELECT round(nvl(SUM(capital - nvl(sal_ret_batch, 0)), 0), 0)
        INTO v_sujeto_e
        FROM ah_cta_certificados ah
       WHERE fec_vencimiento - fec_apertura BETWEEN 2 AND 360
         AND est_cer_batch NOT IN ('V', 'P')
         AND est_batch NOT IN ('T', 'A', 'C', 'X')
         AND nvl(ah.sal_ret_batch, 0) = 0
         AND cod_moneda = v_cod_mon_local
         AND 'N' =
             nvl(fug_obt_paradicional(ah.nro_cuenta, 'EXO_ENCAJES'), 'N');

      -- De 361 a 540 dias
      SELECT round(nvl(SUM(capital - nvl(sal_ret_batch, 0)), 0), 0)
        INTO v_sujeto_f
        FROM ah_cta_certificados ah
       WHERE fec_vencimiento - fec_apertura BETWEEN 361 AND 540
         AND est_cer_batch NOT IN ('V', 'P')
         AND est_batch NOT IN ('T', 'A', 'C', 'X')
         AND nvl(ah.sal_ret_batch, 0) = 0
         AND cod_moneda = v_cod_mon_local
         AND 'N' =
             nvl(fug_obt_paradicional(ah.nro_cuenta, 'EXO_ENCAJES'), 'N');

      -- De 541 o mas dias
      SELECT round(nvl(SUM(capital - nvl(sal_ret_batch, 0)), 0), 0)
        INTO v_sujeto_g
        FROM ah_cta_certificados ah
       WHERE fec_vencimiento - fec_apertura >= 541
         AND est_cer_batch NOT IN ('V', 'P')
         AND est_batch NOT IN ('T', 'A', 'C', 'X')
         AND nvl(ah.sal_ret_batch, 0) = 0
         AND cod_moneda = v_cod_mon_local
         AND 'N' = nvl(fug_obt_paradicional(ah.nro_cuenta, 'EXO_ENCAJES'), 'N');

      v_encaje_h := 0; -- seria ctas a julio 1996 * 0.10
      ----/*  v_encaje_i := round((v_sujeto_d + v_sujeto_e) * 0.17,0); -- Res. 15 del 19/06/2008
      ----/*  v_encaje_i := round((v_sujeto_d + v_sujeto_e) * 0.15,0); -- Cambio el 10/10/2008
      v_encaje_i    := round((v_sujeto_d + v_sujeto_e) * 0.18, 0); -- Cambio el 10/10/2008
      v_encaje_j    := 0; --round(v_sujeto_f * 0.07,0); -- Cambio el 27/02/2009
      v_tot_exigido := round(v_encaje_i + v_encaje_j, 0);
      -- v_mto_remunerar:=  round((v_sujeto_d + v_sujeto_e)*0.08,0); -- Res. 15 del 19/06/2008
      v_mto_remunerar := round((v_sujeto_d + v_sujeto_e) * 0.11, 0); -- Res. 8 del 10/03/2011 ( 18% - 7%)

      --Modificado para traer monto de deposito en BCP--
      v_cod_rub_dep_encaje := fug_obt_pardinamico('COD_RUB_DEP_ENC_LEGAL',
                                                  null,
                                                  null,
                                                  v_cod_mon_local);

      select sum(round((nvl(a.sal_mon_loc_ant, 0) + nvl(a.deb_mon_local, 0) -
                       nvl(a.cre_mon_local, 0)),
                       0))
        into v_bcp_depositado
        from cb_sal_consolidados_dia a
       where a.fecha =
             (select max(b.fecha)
                from cb_sal_consolidados_dia b
               where b.fecha <= p_fec_actual
                 and b.cod_rubro = v_cod_rub_dep_encaje)
         and a.cod_rubro = v_cod_rub_dep_encaje;
      ---------------------------------------------------
      INSERT INTO sb_encajes_ml
        (fecha,
         sal_julio,
         sal_actual,
         sujeto_d,
         sujeto_e,
         sujeto_f,
         sujeto_g,
         encaje_h,
         encaje_i,
         encaje_j,
         tot_exigido,
         mto_remunerar,
         bcp_depositado)
      VALUES
        (p_fec_actual,
         0,
         v_sal_actual,
         v_sujeto_d,
         v_sujeto_e,
         v_sujeto_f,
         v_sujeto_g,
         v_encaje_h,
         v_encaje_i,
         v_encaje_j,
         v_tot_exigido,
         v_mto_remunerar,
         v_bcp_depositado);
    EXCEPTION
      WHEN OTHERS THEN
        raise_application_error(-20000, SQLERRM || ' SB_ENCAJES_ML');
    END;
    /* Calcular encaje legal moneda extranjera */
    PROCEDURE lp_cal_enc_mon_extr(p_fec_actual IN DATE) IS

      v_sujeto_a           sb_encajes_me.sujeto_a%TYPE;
      v_sujeto_c           sb_encajes_me.sujeto_c%TYPE;
      v_sujeto_a_vista     sb_encajes_me.sujeto_a%TYPE;
      v_sujeto_a_cupon     sb_encajes_me.sujeto_a%TYPE;
      v_mto_remunerar      sb_encajes_me.mto_remunerar%TYPE;
      v_tot_exigido        sb_encajes_me.tot_exigido%TYPE;
      v_cotizacion         ge_cotizaciones.val_conversion%TYPE;
      v_encaje_a           sb_encajes_me.encaje_a%TYPE;
      v_encaje_b           sb_encajes_me.encaje_b%TYPE;
      v_encaje_c           sb_encajes_me.encaje_c%TYPE;
      v_encaje_d           sb_encajes_me.encaje_d%TYPE;
      v_sujeto_d           sb_encajes_me.sujeto_d%TYPE;
      v_sujeto_b           sb_encajes_me.sujeto_b%TYPE;
      V_SUJETO_A4          SB_ENCAJES_ME.SUJETO_A%TYPE;
      V_SUJETO_A4_A        SB_ENCAJES_ME.SUJETO_A%TYPE;
      V_SUJETO_A4_B        SB_ENCAJES_ME.SUJETO_A%TYPE;
      V_SUJETO_A4_C        SB_ENCAJES_ME.SUJETO_A%TYPE;
      v_cod_rub_dep_encaje varchar2(15);
      v_bcp_depositado     number(18, 2);
      CURSOR monedas IS
        select distinct (cod_moneda) cod_moneda
          from ge_cuentas
         where cod_moneda <> v_cod_mon_local
           and cod_modulo in (3, 4) --Ahorros y Ctas.Ctes.--
           and cod_modalidad not in (43, 45); --Se excluye 43-Cheque Gerencia y 45-Corresponsales--
    BEGIN
      FOR reg IN monedas LOOP
        -- De 2 y 360 dias
        SELECT nvl(SUM(capital - nvl(sal_ret_batch, 0)), 0)
          INTO v_sujeto_a
          FROM ah_cta_certificados ah
         WHERE fec_vencimiento - fec_apertura BETWEEN 2 AND 360
           AND est_batch NOT IN ('T', 'A', 'C', 'X')
           AND est_cer_batch NOT IN ('V', 'P')
           AND nvl(ah.sal_ret_batch, 0) = 0
           AND cod_moneda = reg.cod_moneda;
        --
        SELECT nvl(SUM(decode(ah.est_cer_batch,
                              'V',
                              ah.sal_tot_batch,
                              'P',
                              ah.sal_tot_batch,
                              ah.sal_tot_batch - ah.capital)),
                   0)
          INTO v_sujeto_a_cupon
          FROM ah_cta_certificados ah
         WHERE est_batch NOT IN ('T', 'A', 'C', 'X')
           AND (est_cer_batch IN ('V', 'P') OR sal_tot_batch > capital)
           AND nvl(ah.sal_ret_batch, 0) = 0
           AND cod_moneda = reg.cod_moneda;
        SELECT nvl(SUM(sal_tot_batch - nvl(sal_ret_batch, 0)), 0) --BRIOS
          INTO v_sujeto_a_vista
          FROM ah_cta_vistas ah
         WHERE cod_moneda = reg.cod_moneda
           AND est_batch NOT IN ('A', 'C'); --Abierta y cancelada

        --CUENTAS CORRIENTES
        --Sujeto al 25%
        --Disponible = Total - Retenido - Bloqueado

        --Disponible > 0 y Bloqueado = 0
        --Encaje = Disponible
        select round(sum(nvl(cc.sal_tot_batch, 0) -
                         nvl(cc.sal_ret_batch, 0) -
                         nvl(cc.sal_blo_batch, 0)),
                     2)
          into V_SUJETO_A4_A
          from cc_cta_corrientes cc
         where cod_moneda = reg.cod_moneda
              --and est_batch not in ('X','A','C')
           AND (NVL(cc.SAL_TOT_BATCH, 0) <> 0 OR
               NVL(cc.SAL_RET_BATCH, 0) <> 0 OR
               NVL(cc.SAL_BLO_BATCH, 0) <> 0)
           and (nvl(cc.sal_tot_batch, 0) - nvl(cc.sal_ret_batch, 0) -
               nvl(cc.sal_blo_batch, 0)) > 0
           and nvl(cc.sal_blo_batch, 0) = 0;

        --Disponible > 0 y Bloqueado > 0
        --Encaje = Disponible + Bloqueado
        select round(sum(nvl(cc.sal_tot_batch, 0) -
                         nvl(cc.sal_ret_batch, 0)),
                     2)
          into V_SUJETO_A4_B
          from cc_cta_corrientes cc
         where cod_moneda = reg.cod_moneda
              --and est_batch not in ('X','A','C')
           AND (NVL(cc.SAL_TOT_BATCH, 0) <> 0 OR
               NVL(cc.SAL_RET_BATCH, 0) <> 0 OR
               NVL(cc.SAL_BLO_BATCH, 0) <> 0)
           and (nvl(cc.sal_tot_batch, 0) - nvl(cc.sal_ret_batch, 0) -
               nvl(cc.sal_blo_batch, 0)) > 0
           and nvl(cc.sal_blo_batch, 0) > 0;

        --Disponible <= 0 y Bloqueado > 0
        --Encaje = Bloqueado
        select round(sum(nvl(cc.sal_blo_batch, 0)), 2)
          into V_SUJETO_A4_C
          from cc_cta_corrientes cc
         where cod_moneda = reg.cod_moneda
              --and est_batch not in ('X','A','C')
           AND (NVL(cc.SAL_TOT_BATCH, 0) <> 0 OR
               NVL(cc.SAL_RET_BATCH, 0) <> 0 OR
               NVL(cc.SAL_BLO_BATCH, 0) <> 0)
           and (nvl(cc.sal_tot_batch, 0) - nvl(cc.sal_ret_batch, 0) -
               nvl(cc.sal_blo_batch, 0)) <= 0
           and nvl(cc.sal_blo_batch, 0) > 0;

        --Saldo total para cuentas corrientes
        V_SUJETO_A4 := nvl(V_SUJETO_A4_A, 0) + nvl(V_SUJETO_A4_B, 0) +
                       nvl(V_SUJETO_A4_C, 0);
        v_sujeto_a  := round(v_sujeto_a + v_sujeto_a_vista +
                             v_sujeto_a_cupon + V_SUJETO_A4,
                             0);
        -- De 361 a 540 dias
        SELECT nvl(SUM(capital - nvl(sal_ret_batch, 0)), 0)
          INTO v_sujeto_b
          FROM ah_cta_certificados ah
         WHERE fec_vencimiento - fec_apertura BETWEEN 361 AND 540
           AND est_cer_batch NOT IN ('V', 'P')
           AND est_batch NOT IN ('T', 'A', 'C', 'X')
           AND nvl(ah.sal_ret_batch, 0) = 0
           AND cod_moneda = reg.cod_moneda
           AND 'N' =
               nvl(fug_obt_paradicional(ah.nro_cuenta, 'EXO_ENCAJES'), 'N');

        -- De 541 0 1080 dias
        SELECT nvl(SUM(capital - nvl(sal_ret_batch, 0)), 0)
          INTO v_sujeto_c
          FROM ah_cta_certificados ah
         WHERE fec_vencimiento - fec_apertura BETWEEN 541 AND 1080
           AND est_cer_batch NOT IN ('V', 'P')
           AND est_batch NOT IN ('T', 'A', 'C', 'X')
           AND nvl(ah.sal_ret_batch, 0) = 0
           AND cod_moneda = reg.cod_moneda
           AND 'N' =
               nvl(fug_obt_paradicional(ah.nro_cuenta, 'EXO_ENCAJES'), 'N');

        -- De 1081 a mas dias
        SELECT nvl(SUM(capital - nvl(sal_ret_batch, 0)), 0)
          INTO v_sujeto_d
          FROM ah_cta_certificados ah
         WHERE fec_vencimiento - fec_apertura >= 1081
           AND est_cer_batch NOT IN ('V', 'P')
           AND est_batch NOT IN ('T', 'A', 'C', 'X')
           AND nvl(ah.sal_ret_batch, 0) = 0
           AND cod_moneda = reg.cod_moneda
           AND 'N' =
               nvl(fug_obt_paradicional(ah.nro_cuenta, 'EXO_ENCAJES'), 'N');

        v_cotizacion    := pag_gen.fu_obt_cotizacion(reg.cod_moneda,
                                                     p_fec_actual);
        v_encaje_a      := round(v_sujeto_a * 0.24, 0);
        v_encaje_b      := round(v_sujeto_b * 0.165, 0);
        v_encaje_c      := 0;
        v_encaje_d      := 0;
        v_mto_remunerar := round((v_sujeto_a * 0.14) + (v_sujeto_b * 0.065),
                                 0);
        v_tot_exigido   := round(v_encaje_a + v_encaje_b + v_encaje_c +
                                 v_encaje_d,
                                 0);

        --Modificado para traer monto de deposito en BCP--
        v_cod_rub_dep_encaje := fug_obt_pardinamico('COD_RUB_DEP_ENC_LEGAL',
                                                    null,
                                                    null,
                                                    reg.cod_moneda);
        select sum(round(nvl(a.sal_mon_rub_ant, 0) +
                         nvl(a.deb_mon_rubro, 0) - nvl(a.cre_mon_rubro, 0),
                         2))
          into v_bcp_depositado
          from cb_sal_consolidados_dia a
         where a.fecha =
               (select max(b.fecha)
                  from cb_sal_consolidados_dia b
                 where b.fecha <= p_fec_actual
                   and b.cod_rubro = v_cod_rub_dep_encaje)
           and a.cod_rubro = v_cod_rub_dep_encaje;
        ---------------------------------------------------
        INSERT INTO sb_encajes_me
          (fecha,
           cod_moneda,
           val_cotizacion,
           sujeto_a,
           sujeto_b,
           sujeto_c,
           sujeto_d,
           encaje_a,
           encaje_b,
           encaje_c,
           encaje_d,
           tot_exigido,
           mto_remunerar,
           bcp_depositado,
           pos_observada)
        VALUES
          (p_fec_actual,
           reg.cod_moneda,
           v_cotizacion,
           v_sujeto_a,
           v_sujeto_b,
           v_sujeto_c,
           v_sujeto_d,
           v_encaje_a,
           v_encaje_b,
           v_encaje_c,
           v_encaje_d,
           v_tot_exigido,
           v_mto_remunerar,
           v_bcp_depositado,
           0);
      END LOOP;
    EXCEPTION
      WHEN OTHERS THEN
        raise_application_error(-20000, SQLERRM || ' SB_ENCAJES_ME');
    END;
    /* Calcular el encaje especial */
    PROCEDURE lp_cal_enc_especial(p_fec_actual IN DATE) IS

      v_mto_encaje sb_encajes_esp.bcp_depositado%TYPE;
      v_redondeo   NUMBER(2);

      CURSOR cta_cancelada IS
        SELECT b.tip_valor,
               c.val_tasa,
               a.capital,
               a.cod_modulo,
               a.cod_modalidad,
               a.cod_moneda,
               a.nro_cuenta,
               a.beneficiario,
               a.fec_apertura,
               nvl(a.fec_pago, p_fec_actual) fec_pago,
               nvl(a.fec_pago, p_fec_actual) - a.fec_apertura dia_transcurridos,
               a.fec_vencimiento
          FROM ah_cta_certificados a, ge_tasas b, ge_tas_fechas c
         WHERE a.fec_pago < a.fec_vencimiento
           AND a.fec_pago > a.fec_apertura --Mismo dia no cancela
           AND a.fec_cam_estado = p_fec_actual
           AND a.estado IN ('P', 'C')
           AND b.cod_tasa = c.cod_tasa
           AND c.cod_tasa =
               fug_obt_pardinamico('SNP_TAS_ENC_LEG_ESPECIAL', a.cod_modulo)
           AND a.cod_moneda = c.cod_moneda
           AND c.cod_modulo = a.cod_modulo
           AND c.fec_vigencia <= pag_cal.fu_obt_fec_actual(a.cod_modulo)
           AND a.fec_vencimiento - a.fec_apertura BETWEEN c.val_minimo AND
               c.val_maximo --plazo
           AND NOT EXISTS (SELECT 1
                  FROM sb_encajes_esp d
                 WHERE d.nro_cuenta = a.nro_cuenta);

    BEGIN

      FOR reg IN cta_cancelada LOOP
        v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                                          reg.cod_modulo,
                                          reg.cod_modalidad,
                                          reg.cod_moneda);

        IF reg.tip_valor = 'P' --Porcentaje
           AND nvl(reg.val_tasa, 0) != 0 THEN
          v_mto_encaje := round((nvl(reg.capital, 0) * reg.val_tasa) / 100,
                                v_redondeo);
        ELSIF reg.tip_valor = 'V' THEN
          --Valor
          v_mto_encaje := reg.val_tasa;
        END IF;

        INSERT INTO sb_encajes_esp
          (nro_cuenta,
           cod_modulo,
           cod_modalidad,
           cod_moneda,
           beneficiario,
           importe,
           fec_emision,
           fec_rescate,
           dia_transcurrido,
           por_encaje,
           bcp_depositado,
           fec_vencimiento)
        VALUES
          (reg.nro_cuenta,
           reg.cod_modulo,
           reg.cod_modalidad,
           reg.cod_moneda,
           reg.beneficiario,
           reg.capital,
           reg.fec_apertura,
           reg.fec_pago,
           reg.dia_transcurridos,
           reg.val_tasa,
           v_mto_encaje,
           reg.fec_vencimiento);

      END LOOP;

    END;
  BEGIN
    p_fec_actual := pag_cal.fu_obt_fec_actual(3);
    rv_gcale     := pag_cal.fu_obt_reg_cal(3);
    nv_cantidad  := rv_gcale.fec_proxima - rv_gcale.fec_actual;
    FOR i IN 1 .. nv_cantidad LOOP
      lp_cal_enc_mon_local(p_fec_actual);
      lp_cal_enc_mon_extr(p_fec_actual);
      lp_cal_enc_especial(p_fec_actual);
      p_fec_actual := p_fec_actual + 1;
    END LOOP;
  END;

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

  /* Recuperar TAN - Res. 012022 */
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
    -- Sexta fase. Presicion 7 decimales
      v_salir := 'N';
      v_tir   := v_valor;
      WHILE v_salir = 'N' LOOP
         v_tir_ant   := v_tir;
         v_tir       := v_tir + 0.0000001;
         v_resultado := 0;
         FOR i IN 1 .. p_can_items LOOP
            v_resultado := v_resultado + (mi_vector(i) / (power((1 + v_tir), i)));
         END LOOP;
         IF v_resultado <= p_inicial THEN
            v_valor := v_tir_ant;
            v_salir := 'S';
         END IF;
      END LOOP;
    ----------------------------
    -- Calcular el valor final
    ----------------------------
    --v_valor := v_valor * 365 / 30 * 100;
    v_valor := v_valor * 365 * 100;
    return round(v_valor, 4);
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

  /* Obtener tasa Nominal. */
  FUNCTION fu_obt_tan(p_tasa IN NUMBER, p_periodo_capit IN NUMBER)
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
  FUNCTION FU_OBT_CUP_VENCIDO(P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE)
    RETURN NUMBER IS

    V_TOT_CUP_VENCIDOS SB_ENCAJES_ML.SAL_ACTUAL%TYPE;
  Begin
    Select nvl(sum(mto_interes), 0)
      into v_tot_cup_vencidos
      from ah_cupones
     where nro_cuenta = p_nro_cuenta
       and estado = 'V';
    return v_tot_cup_vencidos;
  End;
  /* Obtener tasa efectiva de CDA. */
  FUNCTION FU_OBT_TAE_CDA(P_TIP_CAPITALIZACION IN AH_CTA_CERTIFICADOS.TIP_CAPITALIZACION%TYPE,
                          P_VAL_TASA           IN NUMBER,
                          P_PLAZO              IN NUMBER,
                          P_CAPITAL            IN NUMBER) RETURN NUMBER IS
    v_valor number;
    PerCap  number(5);
    v_tan   number;
  begin
    v_tan := pas_bcp.fu_obt_tas_anu_cda(p_tip_capitalizacion,
                                        p_val_tasa,
                                        p_plazo,
                                        p_capital);
    -- periodo de capitalización
    if p_tip_capitalizacion = 1 then
      PerCap := 30;
    elsif p_tip_capitalizacion = 2 then
      PerCap := 60;
    elsif p_tip_capitalizacion = 3 then
      PerCap := 90;
    elsif p_tip_capitalizacion = 4 then
      PerCap := 120;
    elsif p_tip_capitalizacion = 6 then
      PerCap := 180;
    elsif p_tip_capitalizacion = 12 then
      PerCap := 365;
    elsif p_tip_capitalizacion = 99 then
      --PerCap := p_val_tasa;
      PerCap := p_plazo;
      If PerCap > 364 Then
        PerCap := 364;
      End If;
    End if;

    v_valor := pas_bcp.fu_obt_tae(v_tan, percap);
    --v_valor := round(v_valor, 2);
    return v_valor;
  end;
  /* Obtener tasa anual nominal de CDA */
  FUNCTION FU_OBT_TAS_ANU_CDA(P_TIP_CAPITALIZACION IN NUMBER,
                              P_VAL_TASA           IN NUMBER,
                              P_PLAZO              IN NUMBER,
                              P_CAPITAL            IN NUMBER) RETURN NUMBER IS
    v_valor  number;
    PerCap   number(5);
    v_gastos number := 0;
    v_tir    number;
  begin
    v_tir := pas_bcp.fu_obt_tir_cda(p_tip_capitalizacion,
                                    p_val_tasa,
                                    p_plazo,
                                    p_capital);
    -- periodo de capitalización
    if p_tip_capitalizacion = 1 then
      PerCap := 30;
    elsif p_tip_capitalizacion = 2 then
      PerCap := 60;
    elsif p_tip_capitalizacion = 3 then
      PerCap := 90;
    elsif p_tip_capitalizacion = 6 then
      PerCap := 180;
    elsif p_tip_capitalizacion = 12 then
      PerCap := 365;
    elsif p_tip_capitalizacion = 99 then
      PerCap := p_plazo;
      If PerCap > 364 Then
        PerCap := 364;
      End If;
    End if;
    -- El calculo de la tasa anual nominal debe realizarse a traves del calculo de la
    -- TIR, si hay gastos que se deben imputar a la operacion.
    -- De no ser asi, la tasa anual es igual a la tasa efectiva
    if v_gastos > 0 then
      v_valor := pas_bcp.fu_obt_tas_anual(v_tir, p_plazo);
      v_valor := round(v_valor, 2);
    else
      v_valor := p_val_tasa;
    end if;
    return v_valor;
  end;
  /* Obtener el TIR para CDA */
  FUNCTION FU_OBT_TIR_CDA(P_TIP_CAPITALIZACION IN NUMBER,
                          P_VAL_TASA           IN NUMBER,
                          P_PLAZO              IN NUMBER,
                          P_CAPITAL            IN NUMBER) RETURN NUMBER IS
    v_valor         number;
    percap          number(5);
    v_monto_interes number;
    v_numero        varchar2(3900);
    v_gastos        number := 0;
    v_monto_inicial number;
    v_monto_final   number;
  begin
    -- periodo de capitalización
    if p_tip_capitalizacion = 1 then
      PerCap := 30;
    elsif p_tip_capitalizacion = 2 then
      PerCap := 60;
    elsif p_tip_capitalizacion = 3 then
      PerCap := 90;
    elsif p_tip_capitalizacion = 6 then
      PerCap := 180;
    elsif p_tip_capitalizacion = 12 then
      PerCap := 365;
    elsif p_tip_capitalizacion = 99 then
      PerCap := p_plazo;
      If PerCap > 364 Then
        PerCap := 364;
      End If;
    End if;
    If p_val_tasa != 0 Then
      -- calcular el importe de interes ganado en el periodo
      v_monto_interes := pag_gen.fu_cal_int_simple(p_capital,
                                                   PerCap,
                                                   p_val_tasa);
      v_monto_final   := p_capital + v_monto_interes;
      v_monto_inicial := p_capital;

      -- calculo de la TIR por el metodo simplificado, funciona unicamente cuando
      -- hay un solo valor final. si hay varios valores finales, debe utilizarse
      -- el metodo largo
      v_monto_final := v_monto_final - v_gastos;
      v_valor       := ((v_monto_final / v_monto_inicial) - 1) * 100;
    end if;
    return v_valor;
  end;
  /* Obtener tasa efectiva y nominal de prestamo */
  PROCEDURE pr_obt_tas_prestamo(p_nro_solicitud IN pr_cta_prestamos.nro_solicitud%TYPE,
                                p_nro_cuenta    IN pr_cta_prestamos.nro_cuenta%TYPE,
                                p_val_tae       IN OUT NUMBER,
                                p_val_tan       IN OUT NUMBER) IS

    v_cta_recalendarizada VARCHAR2(1);
    v_tot_periodo         number;
    v_num_tae             varchar2(4000);
    v_aux_tae             varchar2(4000);
    v_por_top_gsto        number;
    v_ex_tir              number(1);
    v_modalidad           ge_modalidades.cod_modalidad%type;
    v_modalidad2          ge_modalidades.cod_modalidad%type;
    v_modalidad3          ge_modalidades.cod_modalidad%type;
    v_mod_des_doc         ge_modalidades.cod_modalidad%type;
    v_gastos_esp          number := 0;
    v_val_inicial2      pr_cta_prestamos.mto_capital%TYPE := 0;
    v_inicial2          pr_cta_prestamos.mto_capital%TYPE := 0; -- para descuento de cheques y documentos
    v_fec_ini_nue_tae   ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('FEC_INI_NUE_TAE'); 
    v_fec_ini_prestamo  pr_solicitudes.fec_inicio%type;
    v_old_tae      sb_tas_ape_semanales.val_tas_efectiva%type :=0;
    v_old_tan      sb_tas_ape_semanales.val_tas_efectiva%type :=0;
    
    
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
        FROM pr_sol_cuotas
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
      v_mod_control      ge_modalidades.cod_modalidad%type; -- control modalidad actual
      v_mod_control2     ge_modalidades.cod_modalidad%type; -- control modalidad para evitar harcode
      v_mod_control3     ge_modalidades.cod_modalidad%type; -- control modalidad para evitar harcode
      v_por_mto_solicitado NUMBER;
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
                          round(nvl(car.mto_mon_prestamo, 0) /** 100 / no debe sacar el IVA Decreto N° 6225/2026
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
        select a.monto,a.cod_modalidad -- debe tomar neto Decreto N° 6225/2026
          into v_mto_solicitado, v_mod_control
          from pr_solicitudes a
         where a.nro_solicitud = p_nro_solicitud;

      ELSE
        v_gastos         := 0;
        v_gastos_imp     := 0;
        v_mto_solicitado := 0;
      END IF;
      v_mod_control2 := nvl(fug_obt_pardinamico('COD_MOD_CONTROL','6',v_mod_control),0);
      v_mod_control3 := nvl(fug_obt_pardinamico('COD_MOD_CONTROL2','6',v_mod_control),0);
      ---
      v_aux_mto_imputable   := round(v_mto_solicitado * v_por_top_gsto / 100, 0);
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
            -- Si es menor o igual al limite (5.400.000) entonces verifica si el cargo no supera el 25%
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
              -- Si el cargo es menor o igual al 25% debe verificar que no supere el
              -- Se convierte a la moneda el monto limite para considerar como gastos no imputables...
              v_mto_lim_cargo := pag_gen.fu_con_mon_a_moneda(pag_gen.fu_obt_mon_local,
                                                             p_cod_moneda,
                                                             fug_obt_pardinamico('IMP_MIN_GAS',
                                                                                 6));
              IF v_aux_mto_imputable < v_mto_lim_cargo THEN
                v_mto_lim_cargo := v_aux_mto_imputable;
              END IF;
       
              if v_mto_solicitado > v_mto_lim_prestamo then
                 p_mto_car_imputable := v_gastos_imp;
              else
                if v_aux_mto_imputable < v_gastos_imp then 
                   p_mto_car_imputable := greatest(v_gastos_imp - v_aux_mto_imputable,0);
                else
                   p_mto_car_imputable := greatest(p_mto_car_imputable - v_mto_lim_cargo,0);
                end if;
              end if;
            END IF;
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
    -- obtenemos la fecha de inicio de la solicitud/cuenta
    BEGIN
      IF p_nro_solicitud IS NOT NULL THEN
        SELECT ss.fec_inicio
          INTO v_fec_ini_prestamo
          FROM pr_solicitudes ss
         WHERE ss.nro_solicitud = p_nro_solicitud;
      ELSE
        SELECT s.fec_inicio
          INTO v_fec_ini_prestamo
          FROM pr_cta_prestamos p
          JOIN pr_solicitudes s ON s.nro_solicitud = p.nro_solicitud
         WHERE p.nro_cuenta = p_nro_cuenta;
      END IF;
    EXCEPTION
      WHEN no_data_found THEN
        v_fec_ini_prestamo := pag_cal.fu_obt_fec_actual(6);
      WHEN others THEN
        v_fec_ini_prestamo := pag_cal.fu_obt_fec_actual(6);
    END;

    IF v_fec_ini_prestamo < to_date(v_fec_ini_nue_tae, 'DD/MM/YYYY') THEN
      -- llama a version anterior del pas_bcp
      pas_bcp_ant.pr_obt_tas_prestamo(p_nro_solicitud,
                                      p_nro_cuenta,
                                      v_old_tae,
                                      v_old_tan);
      p_val_tae := round(v_old_tae, 2);
      p_val_tan := round(v_old_tan, 2);
    else
    -- sigue flujo normal nuevo del pas_bcp
    v_contador := 0;
    v_acum_tan := 0;
    v_acum_tae := 0;
    -- Las siguientes variables de paquete se usan para acumular cuotas, días y plazos durante
    -- el loop. Al no resetearse entre llamadas consecutivas en la misma sesión, la segunda llamada
    -- heredaba valores de la anterior produciendo cálculos de TIR incorrectos.
    v_auxiliar     := NULL;
    v_auxiliar1    := NULL;
    v_dias_interes := NULL;
    v_plz_auxiliar := NULL;
    v_val_inicial2 := 0;
    v_inicial2     := 0;
    --- 
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
      -- obtenemos modalidad
        begin
          select cod_modalidad
            into v_modalidad 
            from pr_solicitudes sol
           where sol.nro_solicitud = v_nro_sol_prestamo;
        exception
          when no_data_found then
            null;
          when others then
            null;
        end;
      -- obtenemos modalidad para control
      v_modalidad2 := nvl(fug_obt_pardinamico('COD_MOD_CHE_ROGA'),668);
      v_modalidad3 := nvl(fug_obt_pardinamico('MOD_SUM_IVA',6,v_modalidad),0);
      v_mod_des_doc :=  nvl(fug_obt_pardinamico('COD_MOD_DES_DOC',6,v_modalidad),0);
      -- agregado para che roga o cualquier modalidad de calculo especial
      if v_gastos_imp = 0 and v_modalidad = v_modalidad2 then
        begin
          select round(mto_mon_prestamo, 0) --No debe sacar el IVA - Decreto N° 6225/2026
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
                    FROM pr_sol_cuotas c, pr_solicitudes s
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
                     -- agregado para che roga, en este punto sigue siendo price, es lo mismo de la linea 2301 
                     if v_gastos_imp = 0 and v_modalidad = v_modalidad2 then 
                        v_val_inicial := v_sal_capital - v_gastos_esp;
                     else
                        v_val_inicial := v_sal_capital - v_gastos_imp;
                     end if;
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
              -- pasan de price a flexible
              -- para estas modalidades 68 - 994 suma el iva del interes en cada cuota 
              if v_modalidad = v_modalidad3 then
              v_auxiliar     := v_auxiliar ||
                                TRIM(to_char(cuo.mto_capital +
                                             cuo.mto_interes + round((cuo.mto_interes * 10 / 100 ), v_redondeo) +
                                             cuo.mto_int_documentado)) || '#';
              v_plz_auxiliar := v_plz_auxiliar || round(cuo.dias / 365, 4) || '#';
              else
              v_auxiliar     := v_auxiliar ||
                                TRIM(to_char(cuo.mto_capital +
                                             cuo.mto_interes +
                                             cuo.mto_int_documentado)) || '#';
              v_plz_auxiliar := v_plz_auxiliar || round(cuo.dias / 365, 4) || '#';
              end if;
            END IF;
            v_numero     := v_auxiliar;
            v_plz_numero := v_plz_auxiliar;
            v_num_tae := v_aux_tae;
          END IF;
          -- agregado para descuento de cheques y documentos
          if v_modalidad = v_mod_des_doc then
             v_val_inicial2 := v_val_inicial2 + (cuo.mto_capital - (cuo.mto_interes + cuo.mto_int_documentado)); 
          end if;
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
                     v_tan := round(pas_bcp.fu_obt_tir_esp(v_inicial, -- ver si corresponde
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
                      -- agregado para descuento de cheques y documentos
                     if v_modalidad = v_mod_des_doc  then
                       v_inicial2 := v_val_inicial2 - v_gastos_imp;
                       v_tan:= round(lf_obt_tir_des_documentos(v_inicial2, v_can_cuotas, v_numero1),4);
                     else 
                       v_tan:= round(lf_obt_tir_des_documentos(v_inicial, v_can_cuotas, v_numero1),4);
                     end if;
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
   END IF;
    --p_val_tae := 10;
  END;

  /* Generar los registros de la tabla sb_estratifacion_dep el ultimo día. */
  PROCEDURE PR_GEN_ESTRATIFICACI IS

    V_FEC_ACTUAL DATE;
    v_mon_fuerte ba_monedas.cod_moneda%type;
    v_cot_fuerte ge_cotizaciones.val_venta%type;

    /* Actualiza los registros insertados por cada tipo */
    PROCEDURE LP_UPD_SB_ESTRATIFIC(P_FECHA           IN DATE,
                                   P_CONCEPTO        IN SB_ESTRATIFICACIONES_DEP.CONCEPTO%TYPE,
                                   P_SECUENCIA       IN SB_ESTRATIFICACIONES_DEP.SECUENCIA%TYPE,
                                   P_MONEDA          IN SB_ESTRATIFICACIONES_DEP.COD_MONEDA%TYPE,
                                   P_SECTOR_CONTABLE IN SB_ESTRATIFICACIONES_DEP.COD_SEC_CONTABLE%TYPE,
                                   P_MONTO1          IN SB_ESTRATIFICACIONES_DEP.MONTO%TYPE,
                                   P_CANT1           IN SB_ESTRATIFICACIONES_DEP.CANTIDAD%TYPE,
                                   P_MONTO2          IN SB_ESTRATIFICACIONES_DEP.MONTO%TYPE,
                                   P_CANT2           IN SB_ESTRATIFICACIONES_DEP.CANTIDAD%TYPE,
                                   P_MONTO3          IN SB_ESTRATIFICACIONES_DEP.MONTO%TYPE,
                                   P_CANT3           IN SB_ESTRATIFICACIONES_DEP.CANTIDAD%TYPE,
                                   P_MONTO4          IN SB_ESTRATIFICACIONES_DEP.MONTO%TYPE,
                                   P_CANT4           IN SB_ESTRATIFICACIONES_DEP.CANTIDAD%TYPE,
                                   P_MONTO5          IN SB_ESTRATIFICACIONES_DEP.MONTO%TYPE,
                                   P_CANT5           IN SB_ESTRATIFICACIONES_DEP.CANTIDAD%TYPE,
                                   P_MONTO6          IN SB_ESTRATIFICACIONES_DEP.MONTO%TYPE,
                                   P_CANT6           IN SB_ESTRATIFICACIONES_DEP.CANTIDAD%TYPE);

    /* Insertar SB_ESTRATIFICACION_DEP. */
    PROCEDURE LP_INS_SB_ESTRATIFIC(P_FECHA     IN DATE,
                                   P_SECUENCIA IN NUMERIC,
                                   P_CONCEPTO  IN VARCHAR2,
                                   P_PLZ_HASTA IN VARCHAR2) IS
      V_CONTADOR   NUMBER;
      V_MTO_HASTA  NUMBER(18, 2) := 0;
      V_COD_MONEDA VARCHAR2(3);
      V_SECTOR     VARCHAR2(1);
    BEGIN
      v_contador := 0;
      for reg1 in 1 .. 6 loop
        v_contador := v_contador + 1;
        if v_contador = 1 then
          V_MTO_HASTA := v_rango1;
        elsif v_contador = 2 then
          V_MTO_HASTA := v_rango2;
        elsif v_contador = 3 then
          V_MTO_HASTA := v_rango3;
        elsif v_contador = 4 then
          V_MTO_HASTA := v_rango4;
        elsif v_contador = 5 then
          V_MTO_HASTA := v_rango5;
        else
          V_MTO_HASTA := v_rango6;
        end if;

        v_cod_moneda := pag_gen.fu_obt_mon_local;
        v_Sector     := 'P';

        insert into sb_estratificaciones_dep
          (FECHA,
           COD_MONEDA,
           COD_SEC_CONTABLE,
           MTO_HASTA,
           SECUENCIA,
           CANTIDAD,
           CONCEPTO,
           MONTO,
           PLZ_HASTA)
        values
          (P_FECHA,
           V_COD_MONEDA,
           V_SECTOR,
           V_MTO_HASTA,
           P_SECUENCIA,
           0,
           P_CONCEPTO,
           0,
           P_PLZ_HASTA);

        v_cod_moneda := 'X';
        v_Sector     := 'P';

        insert into sb_estratificaciones_dep
          (FECHA,
           COD_MONEDA,
           COD_SEC_CONTABLE,
           MTO_HASTA,
           SECUENCIA,
           CANTIDAD,
           CONCEPTO,
           MONTO,
           PLZ_HASTA)
        values
          (P_FECHA,
           V_COD_MONEDA,
           V_SECTOR,
           V_MTO_HASTA,
           P_SECUENCIA,
           0,
           P_CONCEPTO,
           0,
           P_PLZ_HASTA);

        v_cod_moneda := pag_gen.fu_obt_mon_local;
        v_Sector     := 'X';

        insert into sb_estratificaciones_dep
          (FECHA,
           COD_MONEDA,
           COD_SEC_CONTABLE,
           MTO_HASTA,
           SECUENCIA,
           CANTIDAD,
           CONCEPTO,
           MONTO,
           PLZ_HASTA)
        values
          (P_FECHA,
           V_COD_MONEDA,
           V_SECTOR,
           V_MTO_HASTA,
           P_SECUENCIA,
           0,
           P_CONCEPTO,
           0,
           P_PLZ_HASTA);

        v_cod_moneda := 'X';
        v_Sector     := 'X';

        insert into sb_estratificaciones_dep
          (FECHA,
           COD_MONEDA,
           COD_SEC_CONTABLE,
           MTO_HASTA,
           SECUENCIA,
           CANTIDAD,
           CONCEPTO,
           MONTO,
           PLZ_HASTA)
        values
          (P_FECHA,
           V_COD_MONEDA,
           V_SECTOR,
           V_MTO_HASTA,
           P_SECUENCIA,
           0,
           P_CONCEPTO,
           0,
           P_PLZ_HASTA);

      end loop;
    END;
    /* Genera Estratificación para Ahorros a la Vista. */
    PROCEDURE LP_GEN_EST_AH_VISTA(P_FEC_ACTUAL IN DATE) IS

      V_SECUENCIA SB_ESTRATIFICACIONES_DEP.SECUENCIA%TYPE;
      V_MONEDA    VARCHAR2(3);
      V_PLAZO     NUMBER(1);
      V_CONCEPTO  SB_ESTRATIFICACIONES_DEP.CONCEPTO%TYPE;
      /*
      Tiene cuatro select con union
      agrupa por sector(publico y no publico),moneda y rango
      1- vista GS
      2- vista USS
      3- vencidas GS
      4- vencidas USS
      */
      tmen1 number(8);
      tmen2 number(8);
      tmen3 number(8);
      tmen4 number(8);
      tmen5 number(8);
      tmen6 number(8);
      --* GS - VISTA - X SECTOR
      CURSOR c_vista IS
        select decode(cl.cod_sec_contable, 'P', 'P', 'I', 'P', 'X') sec_contable,
               decode(cc.cod_moneda, v_moneda, v_moneda, 'X') mone,
               cl.cod_persona,
               --* suma monto
               sum(case
                     when nvl(sal_tot_batch, 0) <= v_rango1 then
                      nvl(sal_tot_batch, 0)
                     else
                      0
                   end) rmen1,
               sum(case
                     when nvl(sal_tot_batch, 0) between (v_rango1 + 1) and
                          v_rango2 then
                      nvl(sal_tot_batch, 0)
                     else
                      0
                   end) rmen2,
               sum(case
                     when nvl(sal_tot_batch, 0) between (v_rango2 + 1) and
                          v_rango3 then
                      nvl(sal_tot_batch, 0)
                     else
                      0
                   end) rmen3,
               sum(case
                     when nvl(sal_tot_batch, 0) between (v_rango3 + 1) and
                          v_rango4 then
                      nvl(sal_tot_batch, 0)
                     else
                      0
                   end) rmen4,
               sum(case
                     when nvl(sal_tot_batch, 0) between (v_rango4 + 1) and
                          v_rango5 then
                      nvl(sal_tot_batch, 0)
                     else
                      0
                   end) rmen5,
               sum(case
                     when nvl(sal_tot_batch, 0) > v_rango6 then
                      nvl(sal_tot_batch, 0)
                     else
                      0
                   end) rmen6,
               --* cuenta
               sum(case
                     when nvl(sal_tot_batch, 0) <= v_rango1 then
                      1
                     else
                      0
                   end) tmen1,
               sum(case
                     when nvl(sal_tot_batch, 0) between (v_rango1 + 1) and
                          v_rango2 then
                      1
                     else
                      0
                   end) tmen2,
               sum(case
                     when nvl(sal_tot_batch, 0) between (v_rango2 + 1) and
                          v_rango3 then
                      1
                     else
                      0
                   end) tmen3,
               sum(case
                     when nvl(sal_tot_batch, 0) between (v_rango3 + 1) and
                          v_rango4 then
                      1
                     else
                      0
                   end) tmen4,
               sum(case
                     when nvl(sal_tot_batch, 0) between (v_rango4 + 1) and
                          v_rango5 then
                      1
                     else
                      0
                   end) tmen5,
               sum(case
                     when nvl(sal_tot_batch, 0) > v_rango6 then
                      1
                     else
                      0
                   end) tmen6
          from ah_cta_vistas cc, ge_cta_clientes ct, ge_clientes cl
         where est_batch not in ('A', 'C', 'X')
           and cc.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and cc.cod_moneda = v_moneda
           and ct.cod_persona = cl.cod_persona
         group by decode(cl.cod_sec_contable, 'P', 'P', 'I', 'P', 'X'),
                  decode(cc.cod_moneda, v_moneda, v_moneda, 'X'),
                  cl.cod_persona
        union
        --* DOLARES - VISTA - X SECTOR
        select decode(cl.cod_sec_contable, 'P', 'P', 'I', 'P', 'X') sec_contable,
               decode(cc.cod_moneda, v_moneda, v_moneda, 'X') mone,
               cl.cod_persona,
               --* suma
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            p_fec_actual)) *
                          nvl(sal_tot_batch, 0)) <= v_rango1 then
                      decode(cc.cod_moneda,
                             v_mon_fuerte,
                             v_cot_fuerte,
                             pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                       p_fec_actual)) *
                      nvl(sal_tot_batch, 0)
                     else
                      0
                   end) rmen1,
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            p_fec_actual)) *
                          nvl(sal_tot_batch, 0)) between (v_rango1 + 1) and
                          v_rango2 then
                      decode(cc.cod_moneda,
                             v_mon_fuerte,
                             v_cot_fuerte,
                             pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                       p_fec_actual)) *
                      nvl(sal_tot_batch, 0)
                     else
                      0
                   end) rmen2,
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            p_fec_actual)) *
                          nvl(sal_tot_batch, 0)) between (v_rango2 + 1) and
                          v_rango3 then
                      decode(cc.cod_moneda,
                             v_mon_fuerte,
                             v_cot_fuerte,
                             pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                       p_fec_actual)) *
                      nvl(sal_tot_batch, 0)
                     else
                      0
                   end) rmen3,
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            p_fec_actual)) *
                          nvl(sal_tot_batch, 0)) between (v_rango3 + 1) and
                          v_rango4 then
                      decode(cc.cod_moneda,
                             v_mon_fuerte,
                             v_cot_fuerte,
                             pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                       p_fec_actual)) *
                      nvl(sal_tot_batch, 0)
                     else
                      0
                   end) rmen4,
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            p_fec_actual)) *
                          nvl(sal_tot_batch, 0)) between (v_rango4 + 1) and
                          v_rango5 then
                      decode(cc.cod_moneda,
                             v_mon_fuerte,
                             v_cot_fuerte,
                             pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                       p_fec_actual)) *
                      nvl(sal_tot_batch, 0)
                     else
                      0
                   end) rmen5,
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            p_fec_actual)) *
                          nvl(sal_tot_batch, 0)) > v_rango6 then
                      decode(cc.cod_moneda,
                             v_mon_fuerte,
                             v_cot_fuerte,
                             pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                       p_fec_actual)) *
                      nvl(sal_tot_batch, 0)
                     else
                      0
                   end) rmen6,
               --* cuenta
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            p_fec_actual)) *
                          nvl(sal_tot_batch, 0)) <= v_rango1 then
                      1
                     else
                      0
                   end) tmen1,
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            p_fec_actual)) *
                          nvl(sal_tot_batch, 0)) between (v_rango1 + 1) and
                          v_rango2 then
                      1
                     else
                      0
                   end) tmen2,
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            p_fec_actual)) *
                          nvl(sal_tot_batch, 0)) between (v_rango2 + 1) and
                          v_rango3 then
                      1
                     else
                      0
                   end) tmen3,
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            p_fec_actual)) *
                          nvl(sal_tot_batch, 0)) between (v_rango3 + 1) and
                          v_rango4 then
                      1
                     else
                      0
                   end) tmen4,
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            p_fec_actual)) *
                          nvl(sal_tot_batch, 0)) between (v_rango4 + 1) and
                          v_rango5 then
                      1
                     else
                      0
                   end) tmen5,
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            p_fec_actual)) *
                          nvl(sal_tot_batch, 0)) > v_rango6 then
                      1
                     else
                      0
                   end) tmen6
          from ah_cta_vistas cc, ge_cta_clientes ct, ge_clientes cl
         where est_batch not in ('A', 'C', 'X')
           and cc.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and cc.cod_moneda <> v_moneda
           and ct.cod_persona = cl.cod_persona
         group by decode(cl.cod_sec_contable, 'P', 'P', 'I', 'P', 'X'),
                  decode(cc.cod_moneda, v_moneda, v_moneda, 'X'),
                  cl.cod_persona
        union
        --* GS - VENCIDAS - X SECTOR
        select decode(cl.cod_sec_contable, 'P', 'P', 'I', 'P', 'X') sec_contable,
               decode(cc.cod_moneda, v_moneda, v_moneda, 'X') mone,
               cl.cod_persona,
               --* suma
               sum(case
                     when nvl(sal_tot_batch, 0) <= v_rango1 then
                      decode(cc.est_cer_batch,
                             'V',
                             cc.sal_tot_batch,
                             'P',
                             cc.sal_tot_batch,
                             nvl(cc.sal_tot_batch, 0) - nvl(cc.capital, 0))
                     else
                      0
                   end) rmen1,
               sum(case
                     when nvl(sal_tot_batch, 0) between (v_rango1 + 1) and
                          v_rango2 then
                      decode(cc.est_cer_batch,
                             'V',
                             cc.sal_tot_batch,
                             'P',
                             cc.sal_tot_batch,
                             nvl(cc.sal_tot_batch, 0) - nvl(cc.capital, 0))
                     else
                      0
                   end) rmen2,
               sum(case
                     when nvl(sal_tot_batch, 0) between (v_rango2 + 1) and
                          v_rango3 then
                      decode(cc.est_cer_batch,
                             'V',
                             cc.sal_tot_batch,
                             'P',
                             cc.sal_tot_batch,
                             nvl(cc.sal_tot_batch, 0) - nvl(cc.capital, 0))
                     else
                      0
                   end) rmen3,
               sum(case
                     when nvl(sal_tot_batch, 0) between (v_rango3 + 1) and
                          v_rango4 then
                      decode(cc.est_cer_batch,
                             'V',
                             cc.sal_tot_batch,
                             'P',
                             cc.sal_tot_batch,
                             nvl(cc.sal_tot_batch, 0) - nvl(cc.capital, 0))
                     else
                      0
                   end) rmen4,
               sum(case
                     when nvl(sal_tot_batch, 0) between (v_rango4 + 1) and
                          v_rango5 then
                      decode(cc.est_cer_batch,
                             'V',
                             cc.sal_tot_batch,
                             'P',
                             cc.sal_tot_batch,
                             nvl(cc.sal_tot_batch, 0) - nvl(cc.capital, 0))
                     else
                      0
                   end) rmen5,
               sum(case
                     when nvl(sal_tot_batch, 0) > v_rango6 then
                      decode(cc.est_cer_batch,
                             'V',
                             cc.sal_tot_batch,
                             'P',
                             cc.sal_tot_batch,
                             nvl(cc.sal_tot_batch, 0) - nvl(cc.capital, 0))
                     else
                      0
                   end) rmen6,
               --* cuenta
               sum(case
                     when nvl(sal_tot_batch, 0) <= v_rango1 then
                      1
                     else
                      0
                   end) tmen1,
               sum(case
                     when nvl(sal_tot_batch, 0) between (v_rango1 + 1) and
                          v_rango2 then
                      1
                     else
                      0
                   end) tmen2,
               sum(case
                     when nvl(sal_tot_batch, 0) between (v_rango2 + 1) and
                          v_rango3 then
                      1
                     else
                      0
                   end) tmen3,
               sum(case
                     when nvl(sal_tot_batch, 0) between (v_rango3 + 1) and
                          v_rango4 then
                      1
                     else
                      0
                   end) tmen4,
               sum(case
                     when nvl(sal_tot_batch, 0) between (v_rango4 + 1) and
                          v_rango5 then
                      1
                     else
                      0
                   end) tmen5,
               sum(case
                     when nvl(sal_tot_batch, 0) > v_rango6 then
                      1
                     else
                      0
                   end) tmen6
          from ah_cta_certificados cc, ge_cta_clientes ct, ge_clientes cl
         where est_batch not in ('A', 'C', 'T', 'X')
           and (fec_vencimiento <= p_fec_actual or sal_tot_batch > capital)
           and sal_tot_batch > 0
           and cc.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and cc.cod_moneda = v_moneda
           and ct.cod_persona = cl.cod_persona
           and nvl(cc.sal_ret_batch, 0) = 0
         group by decode(cl.cod_sec_contable, 'P', 'P', 'I', 'P', 'X'),
                  decode(cc.cod_moneda, v_moneda, v_moneda, 'X'),
                  cl.cod_persona
        union
        --* DOLARES - VENCIDAS - X SECTOR
        select decode(cl.cod_sec_contable, 'P', 'P', 'I', 'P', 'X') sec_contable,
               decode(cc.cod_moneda, v_moneda, v_moneda, 'X') mone,
               cl.cod_persona,
               --* suma
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            p_fec_actual)) *
                          sal_tot_batch) <= v_rango1 then
                      decode(cc.est_cer_batch,
                             'V',
                             decode(cc.cod_moneda,
                                    v_mon_fuerte,
                                    v_cot_fuerte,
                                    pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                              p_fec_actual)) *
                             cc.sal_tot_batch,
                             'P',
                             decode(cc.cod_moneda,
                                    v_mon_fuerte,
                                    v_cot_fuerte,
                                    pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                              p_fec_actual)) *
                             cc.sal_tot_batch,
                             decode(cc.cod_moneda,
                                    v_mon_fuerte,
                                    v_cot_fuerte,
                                    pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                              p_fec_actual)) *
                             (nvl(cc.sal_tot_batch, 0) - nvl(cc.capital, 0)))
                     else
                      0
                   end) rmen1,
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            p_fec_actual)) *
                          sal_tot_batch) between (v_rango1 + 1) and v_rango2 then
                      decode(cc.est_cer_batch,
                             'V',
                             decode(cc.cod_moneda,
                                    v_mon_fuerte,
                                    v_cot_fuerte,
                                    pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                              p_fec_actual)) *
                             cc.sal_tot_batch,
                             'P',
                             decode(cc.cod_moneda,
                                    v_mon_fuerte,
                                    v_cot_fuerte,
                                    pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                              p_fec_actual)) *
                             cc.sal_tot_batch,
                             decode(cc.cod_moneda,
                                    v_mon_fuerte,
                                    v_cot_fuerte,
                                    pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                              p_fec_actual)) *
                             (nvl(cc.sal_tot_batch, 0) - nvl(cc.capital, 0)))
                     else
                      0
                   end) rmen2,
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            p_fec_actual)) *
                          sal_tot_batch) between (v_rango2 + 1) and v_rango3 then
                      decode(cc.est_cer_batch,
                             'V',
                             decode(cc.cod_moneda,
                                    v_mon_fuerte,
                                    v_cot_fuerte,
                                    pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                              p_fec_actual)) *
                             cc.sal_tot_batch,
                             'P',
                             decode(cc.cod_moneda,
                                    v_mon_fuerte,
                                    v_cot_fuerte,
                                    pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                              p_fec_actual)) *
                             cc.sal_tot_batch,
                             decode(cc.cod_moneda,
                                    v_mon_fuerte,
                                    v_cot_fuerte,
                                    pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                              p_fec_actual)) *
                             (nvl(cc.sal_tot_batch, 0) - nvl(cc.capital, 0)))
                     else
                      0
                   end) rmen3,
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            p_fec_actual)) *
                          sal_tot_batch) between (v_rango3 + 1) and v_rango4 then
                      decode(cc.est_cer_batch,
                             'V',
                             decode(cc.cod_moneda,
                                    v_mon_fuerte,
                                    v_cot_fuerte,
                                    pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                              p_fec_actual)) *
                             cc.sal_tot_batch,
                             'P',
                             decode(cc.cod_moneda,
                                    v_mon_fuerte,
                                    v_cot_fuerte,
                                    pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                              p_fec_actual)) *
                             cc.sal_tot_batch,
                             decode(cc.cod_moneda,
                                    v_mon_fuerte,
                                    v_cot_fuerte,
                                    pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                              p_fec_actual)) *
                             (nvl(cc.sal_tot_batch, 0) - nvl(cc.capital, 0)))
                     else
                      0
                   end) rmen4,
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            p_fec_actual)) *
                          sal_tot_batch) between (v_rango4 + 1) and v_rango5 then
                      decode(cc.est_cer_batch,
                             'V',
                             decode(cc.cod_moneda,
                                    v_mon_fuerte,
                                    v_cot_fuerte,
                                    pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                              p_fec_actual)) *
                             cc.sal_tot_batch,
                             'P',
                             decode(cc.cod_moneda,
                                    v_mon_fuerte,
                                    v_cot_fuerte,
                                    pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                              p_fec_actual)) *
                             cc.sal_tot_batch,
                             decode(cc.cod_moneda,
                                    v_mon_fuerte,
                                    v_cot_fuerte,
                                    pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                              p_fec_actual)) *
                             (nvl(cc.sal_tot_batch, 0) - nvl(cc.capital, 0)))
                     else
                      0
                   end) rmen5,
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            p_fec_actual)) *
                          sal_tot_batch) > v_rango6 then
                      decode(cc.est_cer_batch,
                             'V',
                             decode(cc.cod_moneda,
                                    v_mon_fuerte,
                                    v_cot_fuerte,
                                    pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                              p_fec_actual)) *
                             cc.sal_tot_batch,
                             'P',
                             decode(cc.cod_moneda,
                                    v_mon_fuerte,
                                    v_cot_fuerte,
                                    pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                              p_fec_actual)) *
                             cc.sal_tot_batch,
                             decode(cc.cod_moneda,
                                    v_mon_fuerte,
                                    v_cot_fuerte,
                                    pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                              p_fec_actual)) *
                             (nvl(cc.sal_tot_batch, 0) - nvl(cc.capital, 0)))
                     else
                      0
                   end) rmen6,
               --* cuenta
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            p_fec_actual)) *
                          sal_tot_batch) <= v_rango1 then
                      1
                     else
                      0
                   end) tmen1,
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            p_fec_actual)) *
                          sal_tot_batch) between (v_rango1 + 1) and v_rango2 then
                      1
                     else
                      0
                   end) tmen2,
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            p_fec_actual)) *
                          sal_tot_batch) between (v_rango2 + 1) and v_rango3 then
                      1
                     else
                      0
                   end) tmen3,
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            p_fec_actual)) *
                          sal_tot_batch) between (v_rango3 + 1) and v_rango4 then
                      1
                     else
                      0
                   end) tmen4,
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            p_fec_actual)) *
                          sal_tot_batch) between (v_rango4 + 1) and v_rango5 then
                      1
                     else
                      0
                   end) tmen5,
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            p_fec_actual)) *
                          sal_tot_batch) > v_rango6 then
                      1
                     else
                      0
                   end) tmen6
          from ah_cta_certificados cc, ge_cta_clientes ct, ge_clientes cl
         where est_batch not in ('A', 'C', 'T', 'X')
           and (fec_vencimiento <= p_fec_actual or sal_tot_batch > capital)
           and sal_tot_batch > 0
           and cc.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and cc.cod_moneda <> v_moneda
           and ct.cod_persona = cl.cod_persona
           and nvl(cc.sal_ret_batch, 0) = 0
         group by decode(cl.cod_sec_contable, 'P', 'P', 'I', 'P', 'X'),
                  decode(cc.cod_moneda, v_moneda, v_moneda, 'X'),
                  cl.cod_persona
        union
        --* GUARANIES Y DOLARES SOLO BANCOS OFICIALES (BANCO NACIONAL DE FOMENTO)
        select 'X' cod_sec_contable,
               decode(cc.cod_moneda, v_moneda, v_moneda, 'X') mone,
               cl.cod_persona,
               --* suma
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            p_fec_actual)) *
                          nvl(sal_tot_batch, 0)) <= v_rango1 then
                      decode(cc.cod_moneda,
                             v_mon_fuerte,
                             v_cot_fuerte,
                             pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                       p_fec_actual)) *
                      nvl(sal_tot_batch, 0)
                     else
                      0
                   end) rmen1,
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            p_fec_actual)) *
                          nvl(sal_tot_batch, 0)) between (v_rango1 + 1) and
                          v_rango2 then
                      decode(cc.cod_moneda,
                             v_mon_fuerte,
                             v_cot_fuerte,
                             pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                       p_fec_actual)) *
                      nvl(sal_tot_batch, 0)
                     else
                      0
                   end) rmen2,
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            p_fec_actual)) *
                          nvl(sal_tot_batch, 0)) between (v_rango2 + 1) and
                          v_rango3 then
                      decode(cc.cod_moneda,
                             v_mon_fuerte,
                             v_cot_fuerte,
                             pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                       p_fec_actual)) *
                      nvl(sal_tot_batch, 0)
                     else
                      0
                   end) rmen3,
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            p_fec_actual)) *
                          nvl(sal_tot_batch, 0)) between (v_rango3 + 1) and
                          v_rango4 then
                      decode(cc.cod_moneda,
                             v_mon_fuerte,
                             v_cot_fuerte,
                             pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                       p_fec_actual)) *
                      nvl(sal_tot_batch, 0)
                     else
                      0
                   end) rmen4,
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            p_fec_actual)) *
                          nvl(sal_tot_batch, 0)) between (v_rango4 + 1) and
                          v_rango5 then
                      decode(cc.cod_moneda,
                             v_mon_fuerte,
                             v_cot_fuerte,
                             pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                       p_fec_actual)) *
                      nvl(sal_tot_batch, 0)
                     else
                      0
                   end) rmen5,
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            p_fec_actual)) *
                          nvl(sal_tot_batch, 0)) > v_rango6 then
                      decode(cc.cod_moneda,
                             v_mon_fuerte,
                             v_cot_fuerte,
                             pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                       p_fec_actual)) *
                      nvl(sal_tot_batch, 0)
                     else
                      0
                   end) rmen6,
               --* cuenta
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            p_fec_actual)) *
                          nvl(sal_tot_batch, 0)) <= v_rango1 then
                      1
                     else
                      0
                   end) tmen1,
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            p_fec_actual)) *
                          nvl(sal_tot_batch, 0)) between (v_rango1 + 1) and
                          v_rango2 then
                      1
                     else
                      0
                   end) tmen2,
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            p_fec_actual)) *
                          nvl(sal_tot_batch, 0)) between (v_rango2 + 1) and
                          v_rango3 then
                      1
                     else
                      0
                   end) tmen3,
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            p_fec_actual)) *
                          nvl(sal_tot_batch, 0)) between (v_rango3 + 1) and
                          v_rango4 then
                      1
                     else
                      0
                   end) tmen4,
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            p_fec_actual)) *
                          nvl(sal_tot_batch, 0)) between (v_rango4 + 1) and
                          v_rango5 then
                      1
                     else
                      0
                   end) tmen5,
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            p_fec_actual)) *
                          nvl(sal_tot_batch, 0)) > v_rango6 then
                      1
                     else
                      0
                   end) tmen6
          from cc_cta_bancarias cc, ge_cta_clientes ct, ge_clientes cl
         where cc.est_batch not in ('A', 'C', 'X')
           and cc.cod_modalidad = 42
           and cc.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and ct.cod_persona = 25993 --BANCO NACIONAL DE FOMENTO
           and ct.cod_persona = cl.cod_persona
         group by cod_sec_contable,
                  decode(cc.cod_moneda, v_moneda, v_moneda, 'X'),
                  cl.cod_persona
         order by 1, 2;

      -- Para grabar el detalle
      Cursor detalle is
        select decode(cl.cod_sec_contable, 'P', 'P', 'I', 'P', 'X') sec_contable,
               decode(cc.cod_moneda, v_moneda, v_moneda, 'X') mone,
               cc.nro_cuenta,
               nvl(sal_tot_batch, 0) sal_tot_batch
          from ah_cta_vistas cc, ge_cta_clientes ct, ge_clientes cl
         where est_batch not in ('A', 'C', 'X') ---- ,'T') 04/10/04 Delia
           and cc.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and cc.cod_moneda = v_moneda
           and ct.cod_persona = cl.cod_persona
        union
        --* DOLARES - VISTA - X SECTOR
        select decode(cl.cod_sec_contable, 'P', 'P', 'I', 'P', 'X') sec_contable,
               decode(cc.cod_moneda, v_moneda, v_moneda, 'X') mone,
               cc.nro_cuenta,
               decode(cc.cod_moneda,
                      v_mon_fuerte,
                      v_cot_fuerte,
                      pag_gen.fu_obt_cotizacion(cc.cod_moneda, p_fec_actual)) *
               (nvl(sal_tot_batch, 0)) monto
          from ah_cta_vistas cc, ge_cta_clientes ct, ge_clientes cl
         where est_batch not in ('A', 'C', 'X')
           and cc.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and cc.cod_moneda <> v_moneda
           and ct.cod_persona = cl.cod_persona
        union
        --* GS - VENCIDAS - X SECTOR
        select decode(cl.cod_sec_contable, 'P', 'P', 'I', 'P', 'X') sec_contable,
               decode(cc.cod_moneda, v_moneda, v_moneda, 'X') mone,
               cc.nro_cuenta,
               decode(cc.est_cer_batch,
                      'V',
                      cc.sal_tot_batch,
                      'P',
                      cc.sal_tot_batch,
                      nvl(cc.sal_tot_batch, 0) - nvl(cc.capital, 0)) sal_tot_batch
          from ah_cta_certificados cc, ge_cta_clientes ct, ge_clientes cl
         where est_batch not in ('A', 'C', 'T', 'X')
           and (fec_vencimiento <= p_fec_actual or sal_tot_batch > capital)
           and sal_tot_batch > 0
           and cc.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and cc.cod_moneda = v_moneda
           and ct.cod_persona = cl.cod_persona
           and nvl(cc.sal_ret_batch, 0) = 0
        union
        --* DOLARES - VENCIDAS - X SECTOR
        select decode(cl.cod_sec_contable, 'P', 'P', 'I', 'P', 'X') sec_contable,
               decode(cc.cod_moneda, v_moneda, v_moneda, 'X') mone,
               cc.nro_cuenta,
               decode(cc.cod_moneda,
                      v_mon_fuerte,
                      v_cot_fuerte,
                      pag_gen.fu_obt_cotizacion(cc.cod_moneda, p_fec_actual)) *
               decode(cc.est_cer_batch,
                      'V',
                      cc.sal_tot_batch,
                      'P',
                      cc.sal_tot_batch,
                      nvl(cc.sal_tot_batch, 0) - nvl(cc.capital, 0)) monto
          from ah_cta_certificados cc, ge_cta_clientes ct, ge_clientes cl
         where est_batch not in ('A', 'C', 'T', 'X')
           and (fec_vencimiento <= p_fec_actual or sal_tot_batch > capital)
           and sal_tot_batch > 0
           and cc.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and cc.cod_moneda <> v_moneda
           and ct.cod_persona = cl.cod_persona
           and nvl(cc.sal_ret_batch, 0) = 0
        union
        --* GUARANIES Y DOLARES SOLO BANCOS OFICIALES (BANCO NACIONAL DE FOMENTO)
        select 'X' sec_contable,
               decode(cc.cod_moneda, v_moneda, v_moneda, 'X') mone,
               cc.nro_cuenta,
               decode(cc.cod_moneda,
                      v_mon_fuerte,
                      v_cot_fuerte,
                      pag_gen.fu_obt_cotizacion(cc.cod_moneda, p_fec_actual)) *
               (nvl(sal_tot_batch, 0)) monto
          from cc_cta_bancarias cc, ge_cta_clientes ct, ge_clientes cl
         where cc.est_batch not in ('A', 'C', 'X')
           and cc.cod_modalidad = 42
           and cc.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and ct.cod_persona = 25993 --BANCO NACIONAL DE FOMENTO
           and ct.cod_persona = cl.cod_persona
         order by 1, 2;

    BEGIN
      --* Primero inserto todos los registros con monto y cantidad 0
      v_concepto  := 'AHORROS A LA VISTA';
      v_secuencia := 2;
      v_plazo     := 1;
      v_moneda    := pag_gen.fu_obt_mon_local;

      LP_INS_SB_ESTRATIFIC(p_fec_actual, v_secuencia, v_concepto, v_plazo);

      --* ahora voy a actualizar con los datos del cursor
      For reg in c_vista loop
        tmen1 := 0;
        tmen2 := 0;
        tmen3 := 0;
        tmen4 := 0;
        tmen5 := 0;
        tmen6 := 0;
        if reg.rmen1 > 0 then
          tmen1 := 1;
        end if;
        if reg.rmen2 > 0 then
          tmen2 := 1;
        end if;
        if reg.rmen3 > 0 then
          tmen3 := 1;
        end if;
        if reg.rmen4 > 0 then
          tmen4 := 1;
        end if;
        if reg.rmen5 > 0 then
          tmen5 := 1;
        end if;
        if reg.rmen6 > 0 then
          tmen6 := 1;
        end if;
        if tmen1 + tmen2 + tmen3 + tmen4 + tmen5 + tmen6 = 0 then
          tmen1 := 1;
        end if;

        LP_UPD_SB_ESTRATIFIC(p_fec_actual,
                             v_concepto,
                             v_secuencia,
                             reg.mone,
                             reg.sec_contable,
                             reg.rmen1,
                             tmen1,
                             reg.rmen2,
                             tmen2,
                             reg.rmen3,
                             tmen3,
                             reg.rmen4,
                             tmen4,
                             reg.rmen5,
                             tmen5,
                             reg.rmen6,
                             tmen6);
      end loop;
      For reg in detalle loop
        insert into sb_estratificaciones_dep_det
          (FECHA,
           COD_MONEDA,
           COD_SEC_CONTABLE,
           NRO_CUENTA,
           MONTO,
           PLZ_HASTA,
           DESCRIPCION)
        values
          (p_fec_actual,
           reg.mone,
           1,
           reg.nro_cuenta,
           reg.sal_tot_batch,
           v_plazo,
           V_CONCEPTO);
      End loop;
    END;
    ----* FIN PROCEDURE VISTA;
    /* Generar Estratificacion p/ Cta. Cte. */
    PROCEDURE LP_GEN_EST_CTA_CTE(P_FEC_ACTUAL IN DATE) IS

      V_SECUENCIA NUMBER;
      V_CONCEPTO  SB_ESTRATIFICACIONES_DEP.CONCEPTO%TYPE;
      V_MONEDA    VARCHAR2(3);
      V_PLAZO     NUMBER(1);
      /*
      Tiene DOS select con union
      agrupa por sector(publico y no publico),moneda y rango
      1- vista GS
      2- vista USS
      */
      tmen1 number(8);
      tmen2 number(8);
      tmen3 number(8);
      tmen4 number(8);
      tmen5 number(8);
      tmen6 number(8);
      --* GS - CTA.CTE. - X SECTOR
      cursor c_cta_cte is
        select decode(cl.cod_sec_contable, 'P', 'P', 'I', 'P', 'X') sec_contable,
               decode(cc.cod_moneda, v_moneda, v_moneda, 'X') mone,
               cl.cod_persona,
               --* suma monto
               sum(case
                     when nvl(sal_tot_batch, 0) <= v_rango1 then
                      nvl(sal_tot_batch, 0)
                     else
                      0
                   end) rmen1,
               sum(case
                     when nvl(sal_tot_batch, 0) between (v_rango1 + 1) and
                          v_rango2 then
                      nvl(sal_tot_batch, 0)
                     else
                      0
                   end) rmen2,
               sum(case
                     when nvl(sal_tot_batch, 0) between (v_rango2 + 1) and
                          v_rango3 then
                      nvl(sal_tot_batch, 0)
                     else
                      0
                   end) rmen3,
               sum(case
                     when nvl(sal_tot_batch, 0) between (v_rango3 + 1) and
                          v_rango4 then
                      nvl(sal_tot_batch, 0)
                     else
                      0
                   end) rmen4,
               sum(case
                     when nvl(sal_tot_batch, 0) between (v_rango4 + 1) and
                          v_rango5 then
                      nvl(sal_tot_batch, 0)
                     else
                      0
                   end) rmen5,
               sum(case
                     when nvl(sal_tot_batch, 0) > v_rango6 then
                      nvl(sal_tot_batch, 0)
                     else
                      0
                   end) rmen6,
               --* cuenta
               sum(case
                     when nvl(sal_tot_batch, 0) <= v_rango1 then
                      1
                     else
                      0
                   end) tmen1,
               sum(case
                     when nvl(sal_tot_batch, 0) between (v_rango1 + 1) and
                          v_rango2 then
                      1
                     else
                      0
                   end) tmen2,
               sum(case
                     when nvl(sal_tot_batch, 0) between (v_rango2 + 1) and
                          v_rango3 then
                      1
                     else
                      0
                   end) tmen3,
               sum(case
                     when nvl(sal_tot_batch, 0) between (v_rango3 + 1) and
                          v_rango4 then
                      1
                     else
                      0
                   end) tmen4,
               sum(case
                     when nvl(sal_tot_batch, 0) between (v_rango4 + 1) and
                          v_rango5 then
                      1
                     else
                      0
                   end) tmen5,
               sum(case
                     when nvl(sal_tot_batch, 0) > v_rango6 then
                      1
                     else
                      0
                   end) tmen6
          from cc_cta_corrientes cc, ge_cta_clientes ct, ge_clientes cl
         where est_batch not in ('A', 'C', 'X')
           and cc.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and cc.cod_moneda = v_moneda
           and nvl(cc.sal_tot_batch, 0) >= 0 --sin sobregiros
           and ct.cod_persona = cl.cod_persona
         group by decode(cl.cod_sec_contable, 'P', 'P', 'I', 'P', 'X'),
                  decode(cc.cod_moneda, v_moneda, v_moneda, 'X'),
                  cl.cod_persona
        union
        --* DOLARES - CTA.CTE. - X SECTOR
        select decode(cl.cod_sec_contable, 'P', 'P', 'I', 'P', 'X') sec_contable,
               decode(cc.cod_moneda, v_moneda, v_moneda, 'X') mone,
               cl.cod_persona,
               --* suma
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            p_fec_actual)) *
                          nvl(sal_tot_batch, 0)) <= v_rango1 then
                      decode(cc.cod_moneda,
                             v_mon_fuerte,
                             v_cot_fuerte,
                             pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                       p_fec_actual)) *
                      (nvl(sal_tot_batch, 0))
                     else
                      0
                   end) rmen1,
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            p_fec_actual)) *
                          nvl(sal_tot_batch, 0)) between (v_rango1 + 1) and
                          v_rango2 then
                      decode(cc.cod_moneda,
                             v_mon_fuerte,
                             v_cot_fuerte,
                             pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                       p_fec_actual)) *
                      (nvl(sal_tot_batch, 0))
                     else
                      0
                   end) rmen2,
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            p_fec_actual)) *
                          nvl(sal_tot_batch, 0)) between (v_rango2 + 1) and
                          v_rango3 then
                      decode(cc.cod_moneda,
                             v_mon_fuerte,
                             v_cot_fuerte,
                             pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                       p_fec_actual)) *
                      (nvl(sal_tot_batch, 0))
                     else
                      0
                   end) rmen3,
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            p_fec_actual)) *
                          nvl(sal_tot_batch, 0)) between (v_rango3 + 1) and
                          v_rango4 then
                      decode(cc.cod_moneda,
                             v_mon_fuerte,
                             v_cot_fuerte,
                             pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                       p_fec_actual)) *
                      (nvl(sal_tot_batch, 0))
                     else
                      0
                   end) rmen4,
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            p_fec_actual)) *
                          nvl(sal_tot_batch, 0)) between (v_rango4 + 1) and
                          v_rango5 then
                      decode(cc.cod_moneda,
                             v_mon_fuerte,
                             v_cot_fuerte,
                             pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                       p_fec_actual)) *
                      (nvl(sal_tot_batch, 0))
                     else
                      0
                   end) rmen5,
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            p_fec_actual)) *
                          nvl(sal_tot_batch, 0)) > v_rango6 then
                      decode(cc.cod_moneda,
                             v_mon_fuerte,
                             v_cot_fuerte,
                             pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                       p_fec_actual)) *
                      (nvl(sal_tot_batch, 0))
                     else
                      0
                   end) rmen6,
               --* cuenta
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            p_fec_actual)) *
                          nvl(sal_tot_batch, 0)) <= v_rango1 then
                      1
                     else
                      0
                   end) tmen1,
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            p_fec_actual)) *
                          nvl(sal_tot_batch, 0)) between (v_rango1 + 1) and
                          v_rango2 then
                      1
                     else
                      0
                   end) tmen2,
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            p_fec_actual)) *
                          nvl(sal_tot_batch, 0)) between (v_rango2 + 1) and
                          v_rango3 then
                      1
                     else
                      0
                   end) tmen3,
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            p_fec_actual)) *
                          nvl(sal_tot_batch, 0)) between (v_rango3 + 1) and
                          v_rango4 then
                      1
                     else
                      0
                   end) tmen4,
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            p_fec_actual)) *
                          nvl(sal_tot_batch, 0)) between (v_rango4 + 1) and
                          v_rango5 then
                      1
                     else
                      0
                   end) tmen5,
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            p_fec_actual)) *
                          nvl(sal_tot_batch, 0)) > v_rango6 then
                      1
                     else
                      0
                   end) tmen6
          from cc_cta_corrientes cc, ge_cta_clientes ct, ge_clientes cl
         where est_batch not in ('A', 'C', 'X')
           and cc.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and cc.cod_moneda <> v_moneda
           and nvl(cc.sal_tot_batch, 0) >= 0 --sin sobregiros
           and ct.cod_persona = cl.cod_persona
         group by decode(cl.cod_sec_contable, 'P', 'P', 'I', 'P', 'X'),
                  decode(cc.cod_moneda, v_moneda, v_moneda, 'X'),
                  cl.cod_persona
         order by 1, 2;

      -- Detalle de Cta. Cte.
      Cursor detalle is
        select decode(cl.cod_sec_contable, 'P', 'P', 'I', 'P', 'X') sec_contable,
               decode(cc.cod_moneda, v_moneda, v_moneda, 'X') mone,
               cc.nro_cuenta,
               (nvl(sal_tot_batch, 0)) sal_tot_batch
          from cc_cta_corrientes cc, ge_cta_clientes ct, ge_clientes cl
         where est_batch not in ('A', 'C', 'X')
           and cc.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and cc.cod_moneda = v_moneda
           and nvl(cc.sal_tot_batch, 0) >= 0 --sin sobregiros
           and ct.cod_persona = cl.cod_persona
        union
        --* DOLARES - CTA.CTE. - X SECTOR
        select decode(cl.cod_sec_contable, 'P', 'P', 'I', 'P', 'X') sec_contable,
               decode(cc.cod_moneda, v_moneda, v_moneda, 'X') mone,
               cc.nro_cuenta,
               decode(cc.cod_moneda,
                      v_mon_fuerte,
                      v_cot_fuerte,
                      pag_gen.fu_obt_cotizacion(cc.cod_moneda, p_fec_actual)) *
               (nvl(sal_tot_batch, 0)) monto
          from cc_cta_corrientes cc, ge_cta_clientes ct, ge_clientes cl
         where est_batch not in ('A', 'C', 'X')
           and cc.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and cc.cod_moneda <> v_moneda
           and nvl(cc.sal_tot_batch, 0) >= 0 --sin sobregiros
           and ct.cod_persona = cl.cod_persona
         order by 1, 2;
    BEGIN
      --* Primero inserto todos los registros con monto y cantidad 0
      v_concepto  := 'CUENTAS CORRIENTES';
      v_secuencia := 1;
      v_plazo     := 1;
      v_moneda    := pag_gen.fu_obt_mon_local;

      LP_INS_SB_ESTRATIFIC(p_fec_actual, v_secuencia, v_concepto, v_plazo);

      --* ahora voy a actualizar con los datos del cursor

      For reg in c_cta_cte loop
        tmen1 := 0;
        tmen2 := 0;
        tmen3 := 0;
        tmen4 := 0;
        tmen5 := 0;
        tmen6 := 0;
        if reg.rmen1 > 0 then
          tmen1 := 1;
        end if;
        if reg.rmen2 > 0 then
          tmen2 := 1;
        end if;
        if reg.rmen3 > 0 then
          tmen3 := 1;
        end if;
        if reg.rmen4 > 0 then
          tmen4 := 1;
        end if;
        if reg.rmen5 > 0 then
          tmen5 := 1;
        end if;
        if reg.rmen6 > 0 then
          tmen6 := 1;
        end if;
        if tmen1 + tmen2 + tmen3 + tmen4 + tmen5 + tmen6 = 0 then
          tmen1 := 1;
        end if;
        LP_UPD_SB_ESTRATIFIC(p_fec_actual,
                             v_concepto,
                             v_secuencia,
                             reg.mone,
                             reg.sec_contable,
                             reg.rmen1,
                             tmen1,
                             reg.rmen2,
                             tmen2,
                             reg.rmen3,
                             tmen3,
                             reg.rmen4,
                             tmen4,
                             reg.rmen5,
                             tmen5,
                             reg.rmen6,
                             tmen6);
      end loop;
      For reg in detalle loop
        insert into sb_estratificaciones_dep_det
          (FECHA,
           COD_MONEDA,
           COD_SEC_CONTABLE,
           NRO_CUENTA,
           MONTO,
           PLZ_HASTA,
           DESCRIPCION)
        values
          (p_fec_actual,
           reg.mone,
           1,
           reg.nro_cuenta,
           reg.sal_tot_batch,
           v_plazo,
           V_CONCEPTO);
      End loop;
    END;
    ----* FIN PROCEDURE CTA. CTE.;

    /* Generar estratificación para Dep. a Plazo Fijo menor o mayor 90 dias. */
    PROCEDURE LP_GEN_EST_PLZ_FIJO(P_FEC_ACTUAL IN DATE) IS

      V_CONCEPTO  VARCHAR2(60);
      V_MONEDA    VARCHAR2(3);
      V_SECUENCIA NUMBER;
      V_PLAZO     NUMBER;
      /*
      Tiene 4 select con union
      agrupa por sector(publico y no publico),moneda y rango
      1- plazo fijo  GS   <= 90 dias
      2- plazo fijo GS    > 90 dias
      3- plazo fijo  USS  <= 90 dias
      4- plazo fijo USS   > 90 dias

      */
      tmen1 number(8);
      tmen2 number(8);
      tmen3 number(8);
      tmen4 number(8);
      tmen5 number(8);
      tmen6 number(8);
      --* GS - PLAZO FIJO - X SECTOR  < 90 dias
      cursor c_cta_cte is
        select decode(cl.cod_sec_contable, 'P', 'P', 'I', 'P', 'X') sec_contable,
               decode(cc.cod_moneda, v_moneda, v_moneda, 'X') mone,
               cl.cod_persona,
               'MEN90' LUGAR,
               --* suma monto
               sum(case
                     when nvl(sal_tot_batch, 0) <= v_rango1 then
                      nvl(capital, 0)
                     else
                      0
                   end) rmen1,
               sum(case
                     when nvl(sal_tot_batch, 0) between (v_rango1 + 1) and
                          v_rango2 then
                      nvl(capital, 0)
                     else
                      0
                   end) rmen2,
               sum(case
                     when nvl(sal_tot_batch, 0) between (v_rango2 + 1) and
                          v_rango3 then
                      nvl(capital, 0)
                     else
                      0
                   end) rmen3,
               sum(case
                     when nvl(sal_tot_batch, 0) between (v_rango3 + 1) and
                          v_rango4 then
                      nvl(capital, 0)
                     else
                      0
                   end) rmen4,
               sum(case
                     when nvl(sal_tot_batch, 0) between (v_rango4 + 1) and
                          v_rango5 then
                      nvl(capital, 0)
                     else
                      0
                   end) rmen5,
               sum(case
                     when nvl(sal_tot_batch, 0) > v_rango6 then
                      nvl(capital, 0)
                     else
                      0
                   end) rmen6,
               --* cuenta
               sum(case
                     when nvl(sal_tot_batch, 0) <= v_rango1 then
                      1
                     else
                      0
                   end) tmen1,
               sum(case
                     when nvl(sal_tot_batch, 0) between (v_rango1 + 1) and
                          v_rango2 then
                      1
                     else
                      0
                   end) tmen2,
               sum(case
                     when nvl(sal_tot_batch, 0) between (v_rango2 + 1) and
                          v_rango3 then
                      1
                     else
                      0
                   end) tmen3,
               sum(case
                     when nvl(sal_tot_batch, 0) between (v_rango3 + 1) and
                          v_rango4 then
                      1
                     else
                      0
                   end) tmen4,
               sum(case
                     when nvl(sal_tot_batch, 0) between (v_rango4 + 1) and
                          v_rango5 then
                      1
                     else
                      0
                   end) tmen5,
               sum(case
                     when nvl(sal_tot_batch, 0) > v_rango6 then
                      1
                     else
                      0
                   end) tmen6
          from ah_cta_certificados cc, ge_cta_clientes ct, ge_clientes cl
         where cc.est_batch NOT IN ('T', 'A', 'C', 'X', 'V', 'P')
           and sal_tot_batch > 0
           and cc.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and cc.fec_vencimiento > p_fec_actual
           and cc.cod_moneda = v_moneda
           and ct.cod_persona = cl.cod_persona
           and (cc.fec_vencimiento - cc.fec_apertura) <= 90
           and nvl(cc.sal_ret_batch, 0) = 0
         group by decode(cl.cod_sec_contable, 'P', 'P', 'I', 'P', 'X'),
                  decode(cc.cod_moneda, v_moneda, v_moneda, 'X'),
                  cl.cod_persona
        union --* GS - PLAZO FIJO - X SECTOR  > 90 dias
        select decode(cl.cod_sec_contable, 'P', 'P', 'I', 'P', 'X') sec_contable,
               decode(cc.cod_moneda, v_moneda, v_moneda, 'X') mone,
               cl.cod_persona,
               'MAY90' LUGAR,
               --* suma monto
               sum(case
                     when nvl(sal_tot_batch, 0) <= v_rango1 then
                      nvl(capital, 0)
                     else
                      0
                   end) rmen1,
               sum(case
                     when nvl(sal_tot_batch, 0) between (v_rango1 + 1) and
                          v_rango2 then
                      nvl(capital, 0)
                     else
                      0
                   end) rmen2,
               sum(case
                     when nvl(sal_tot_batch, 0) between (v_rango2 + 1) and
                          v_rango3 then
                      nvl(capital, 0)
                     else
                      0
                   end) rmen3,
               sum(case
                     when nvl(sal_tot_batch, 0) between (v_rango3 + 1) and
                          v_rango4 then
                      nvl(capital, 0)
                     else
                      0
                   end) rmen4,
               sum(case
                     when nvl(sal_tot_batch, 0) between (v_rango4 + 1) and
                          v_rango5 then
                      nvl(capital, 0)
                     else
                      0
                   end) rmen5,
               sum(case
                     when nvl(sal_tot_batch, 0) > v_rango6 then
                      nvl(capital, 0)
                     else
                      0
                   end) rmen6,
               --* cuenta
               sum(case
                     when nvl(sal_tot_batch, 0) <= v_rango1 then
                      1
                     else
                      0
                   end) tmen1,
               sum(case
                     when nvl(sal_tot_batch, 0) between (v_rango1 + 1) and
                          v_rango2 then
                      1
                     else
                      0
                   end) tmen2,
               sum(case
                     when nvl(sal_tot_batch, 0) between (v_rango2 + 1) and
                          v_rango3 then
                      1
                     else
                      0
                   end) tmen3,
               sum(case
                     when nvl(sal_tot_batch, 0) between (v_rango3 + 1) and
                          v_rango4 then
                      1
                     else
                      0
                   end) tmen4,
               sum(case
                     when nvl(sal_tot_batch, 0) between (v_rango4 + 1) and
                          v_rango5 then
                      1
                     else
                      0
                   end) tmen5,
               sum(case
                     when nvl(sal_tot_batch, 0) > v_rango6 then
                      1
                     else
                      0
                   end) tmen6
          from ah_cta_certificados cc, ge_cta_clientes ct, ge_clientes cl
         where cc.est_batch NOT IN ('T', 'A', 'C', 'X', 'V', 'P')
           and sal_tot_batch > 0
           and cc.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and cc.fec_vencimiento > p_fec_actual
           and cc.cod_moneda = v_moneda
           and ct.cod_persona = cl.cod_persona
           and (cc.fec_vencimiento - cc.fec_apertura) between 91 and 180
           and nvl(cc.sal_ret_batch, 0) = 0
         group by decode(cl.cod_sec_contable, 'P', 'P', 'I', 'P', 'X'),
                  decode(cc.cod_moneda, v_moneda, v_moneda, 'X'),
                  cl.cod_persona
        union
        --* DOLARES - PLAZO FIJO - X SECTOR  < 90 dias
        select decode(cl.cod_sec_contable, 'P', 'P', 'I', 'P', 'X') sec_contable,
               decode(cc.cod_moneda, v_moneda, v_moneda, 'X') mone,
               cl.cod_persona,
               'MEN90' LUGAR,
               --* suma
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            p_fec_actual)) *
                          nvl(sal_tot_batch, 0)) <= v_rango1 then
                      decode(cc.cod_moneda,
                             v_mon_fuerte,
                             v_cot_fuerte,
                             pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                       p_fec_actual)) *
                      nvl(capital, 0)
                     else
                      0
                   end) rmen1,
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            p_fec_actual)) *
                          nvl(sal_tot_batch, 0)) between (v_rango1 + 1) and
                          v_rango2 then
                      decode(cc.cod_moneda,
                             v_mon_fuerte,
                             v_cot_fuerte,
                             pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                       p_fec_actual)) *
                      nvl(capital, 0)
                     else
                      0
                   end) rmen2,
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            p_fec_actual)) *
                          nvl(sal_tot_batch, 0)) between (v_rango2 + 1) and
                          v_rango3 then
                      decode(cc.cod_moneda,
                             v_mon_fuerte,
                             v_cot_fuerte,
                             pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                       p_fec_actual)) *
                      nvl(capital, 0)
                     else
                      0
                   end) rmen3,
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            p_fec_actual)) *
                          nvl(sal_tot_batch, 0)) between (v_rango3 + 1) and
                          v_rango4 then
                      decode(cc.cod_moneda,
                             v_mon_fuerte,
                             v_cot_fuerte,
                             pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                       p_fec_actual)) *
                      nvl(capital, 0)
                     else
                      0
                   end) rmen4,
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            p_fec_actual)) *
                          nvl(sal_tot_batch, 0)) between (v_rango4 + 1) and
                          v_rango5 then
                      decode(cc.cod_moneda,
                             v_mon_fuerte,
                             v_cot_fuerte,
                             pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                       p_fec_actual)) *
                      nvl(capital, 0)
                     else
                      0
                   end) rmen5,
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            p_fec_actual)) *
                          nvl(sal_tot_batch, 0)) > v_rango6 then
                      decode(cc.cod_moneda,
                             v_mon_fuerte,
                             v_cot_fuerte,
                             pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                       p_fec_actual)) *
                      nvl(capital, 0)
                     else
                      0
                   end) rmen6,
               --* cuenta
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            p_fec_actual)) *
                          nvl(sal_tot_batch, 0)) <= v_rango1 then
                      1
                     else
                      0
                   end) tmen1,
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            p_fec_actual)) *
                          nvl(sal_tot_batch, 0)) between (v_rango1 + 1) and
                          v_rango2 then
                      1
                     else
                      0
                   end) tmen2,
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            p_fec_actual)) *
                          nvl(sal_tot_batch, 0)) between (v_rango2 + 1) and
                          v_rango3 then
                      1
                     else
                      0
                   end) tmen3,
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            p_fec_actual)) *
                          nvl(sal_tot_batch, 0)) between (v_rango3 + 1) and
                          v_rango4 then
                      1
                     else
                      0
                   end) tmen4,
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            p_fec_actual)) *
                          nvl(sal_tot_batch, 0)) between (v_rango4 + 1) and
                          v_rango5 then
                      1
                     else
                      0
                   end) tmen5,
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            p_fec_actual)) *
                          nvl(sal_tot_batch, 0)) > v_rango6 then
                      1
                     else
                      0
                   end) tmen6
          from ah_cta_certificados cc, ge_cta_clientes ct, ge_clientes cl
         where cc.est_batch NOT IN ('T', 'A', 'C', 'X', 'V', 'P')
           and sal_tot_batch > 0
           and cc.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and cc.fec_vencimiento > p_fec_actual
           and cc.cod_moneda <> v_moneda
           and ct.cod_persona = cl.cod_persona
           and (cc.fec_vencimiento - cc.fec_apertura) <= 90
           and nvl(cc.sal_ret_batch, 0) = 0
         group by decode(cl.cod_sec_contable, 'P', 'P', 'I', 'P', 'X'),
                  decode(cc.cod_moneda, v_moneda, v_moneda, 'X'),
                  cl.cod_persona
        union --* DOLARES - PLAZO FIJO - X SECTOR  > 90 dias
        select decode(cl.cod_sec_contable, 'P', 'P', 'I', 'P', 'X') sec_contable,
               decode(cc.cod_moneda, v_moneda, v_moneda, 'X') mone,
               cl.cod_persona,
               'MAY90' LUGAR,
               --* suma
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            p_fec_actual)) *
                          nvl(sal_tot_batch, 0)) <= v_rango1 then
                      decode(cc.cod_moneda,
                             v_mon_fuerte,
                             v_cot_fuerte,
                             pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                       p_fec_actual)) *
                      nvl(capital, 0)
                     else
                      0
                   end) rmen1,
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            p_fec_actual)) *
                          nvl(sal_tot_batch, 0)) between (v_rango1 + 1) and
                          v_rango2 then
                      decode(cc.cod_moneda,
                             v_mon_fuerte,
                             v_cot_fuerte,
                             pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                       p_fec_actual)) *
                      nvl(capital, 0)
                     else
                      0
                   end) rmen2,
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            p_fec_actual)) *
                          nvl(sal_tot_batch, 0)) between (v_rango2 + 1) and
                          v_rango3 then
                      decode(cc.cod_moneda,
                             v_mon_fuerte,
                             v_cot_fuerte,
                             pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                       p_fec_actual)) *
                      nvl(capital, 0)
                     else
                      0
                   end) rmen3,
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            p_fec_actual)) *
                          nvl(sal_tot_batch, 0)) between (v_rango3 + 1) and
                          v_rango4 then
                      decode(cc.cod_moneda,
                             v_mon_fuerte,
                             v_cot_fuerte,
                             pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                       p_fec_actual)) *
                      nvl(capital, 0)
                     else
                      0
                   end) rmen4,
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            p_fec_actual)) *
                          nvl(sal_tot_batch, 0)) between (v_rango4 + 1) and
                          v_rango5 then
                      decode(cc.cod_moneda,
                             v_mon_fuerte,
                             v_cot_fuerte,
                             pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                       p_fec_actual)) *
                      nvl(capital, 0)
                     else
                      0
                   end) rmen5,
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            p_fec_actual)) *
                          nvl(sal_tot_batch, 0)) > v_rango6 then
                      decode(cc.cod_moneda,
                             v_mon_fuerte,
                             v_cot_fuerte,
                             pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                       p_fec_actual)) *
                      nvl(capital, 0)
                     else
                      0
                   end) rmen6,
               --* cuenta
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            p_fec_actual)) *
                          nvl(sal_tot_batch, 0)) <= v_rango1 then
                      1
                     else
                      0
                   end) tmen1,
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            p_fec_actual)) *
                          nvl(sal_tot_batch, 0)) between (v_rango1 + 1) and
                          v_rango2 then
                      1
                     else
                      0
                   end) tmen2,
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            p_fec_actual)) *
                          nvl(sal_tot_batch, 0)) between (v_rango2 + 1) and
                          v_rango3 then
                      1
                     else
                      0
                   end) tmen3,
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            p_fec_actual)) *
                          nvl(sal_tot_batch, 0)) between (v_rango3 + 1) and
                          v_rango4 then
                      1
                     else
                      0
                   end) tmen4,
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            p_fec_actual)) *
                          nvl(sal_tot_batch, 0)) between (v_rango4 + 1) and
                          v_rango5 then
                      1
                     else
                      0
                   end) tmen5,
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            p_fec_actual)) *
                          nvl(sal_tot_batch, 0)) > v_rango6 then
                      1
                     else
                      0
                   end) tmen6
          from ah_cta_certificados cc, ge_cta_clientes ct, ge_clientes cl
         where cc.est_batch NOT IN ('T', 'A', 'C', 'X', 'V', 'P')
           and sal_tot_batch > 0
           and cc.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and cc.fec_vencimiento > p_fec_actual
           and cc.cod_moneda <> v_moneda
           and ct.cod_persona = cl.cod_persona
           and (cc.fec_vencimiento - cc.fec_apertura) between 91 and 180
           and nvl(cc.sal_ret_batch, 0) = 0
         group by decode(cl.cod_sec_contable, 'P', 'P', 'I', 'P', 'X'),
                  decode(cc.cod_moneda, v_moneda, v_moneda, 'X'),
                  cl.cod_persona
         order by 1, 2;

      Cursor detalle is
        select decode(cl.cod_sec_contable, 'P', 'P', 'I', 'P', 'X') sec_contable,
               decode(cc.cod_moneda, v_moneda, v_moneda, 'X') mone,
               cc.nro_cuenta,
               'MEN90' LUGAR,
               capital sal_tot_batch
          from ah_cta_certificados cc, ge_cta_clientes ct, ge_clientes cl
         where cc.est_batch NOT IN ('T', 'A', 'C', 'X', 'V', 'P')
           and sal_tot_batch > 0
           and cc.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and cc.fec_vencimiento > p_fec_actual
           and cc.cod_moneda = v_moneda
           and ct.cod_persona = cl.cod_persona
           and (cc.fec_vencimiento - cc.fec_apertura) <= 90
           and nvl(cc.sal_ret_batch, 0) = 0
        union --* GS - PLAZO FIJO - X SECTOR  > 90 dias
        select decode(cl.cod_sec_contable, 'P', 'P', 'I', 'P', 'X') sec_contable,
               decode(cc.cod_moneda, v_moneda, v_moneda, 'X') mone,
               cc.nro_cuenta,
               'MAY90' LUGAR,
               capital sal_tot_batch
          from ah_cta_certificados cc, ge_cta_clientes ct, ge_clientes cl
         where cc.est_batch NOT IN ('T', 'A', 'C', 'X', 'V', 'P')
           and sal_tot_batch > 0
           and cc.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and cc.fec_vencimiento > p_fec_actual
           and cc.cod_moneda = v_moneda
           and ct.cod_persona = cl.cod_persona
           and (cc.fec_vencimiento - cc.fec_apertura) between 91 and 180
           and nvl(cc.sal_ret_batch, 0) = 0
        union
        --* DOLARES - PLAZO FIJO - X SECTOR  < 90 dias
        select decode(cl.cod_sec_contable, 'P', 'P', 'I', 'P', 'X') sec_contable,
               decode(cc.cod_moneda, v_moneda, v_moneda, 'X') mone,
               cc.nro_cuenta,
               'MEN90' LUGAR,
               decode(cc.cod_moneda,
                      v_mon_fuerte,
                      v_cot_fuerte,
                      pag_gen.fu_obt_cotizacion(cc.cod_moneda, p_fec_actual)) *
               nvl(capital, 0) monto
          from ah_cta_certificados cc, ge_cta_clientes ct, ge_clientes cl
         where cc.est_batch NOT IN ('T', 'A', 'C', 'X', 'V', 'P')
           and sal_tot_batch > 0
           and cc.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and cc.fec_vencimiento > p_fec_actual
           and cc.cod_moneda <> v_moneda
           and ct.cod_persona = cl.cod_persona
           and (cc.fec_vencimiento - cc.fec_apertura) <= 90
           and nvl(cc.sal_ret_batch, 0) = 0
        union --* DOLARES - PLAZO FIJO - X SECTOR  > 90 dias
        select decode(cl.cod_sec_contable, 'P', 'P', 'I', 'P', 'X') sec_contable,
               decode(cc.cod_moneda, v_moneda, v_moneda, 'X') mone,
               cc.nro_cuenta,
               'MAY90' LUGAR,
               decode(cc.cod_moneda,
                      v_mon_fuerte,
                      v_cot_fuerte,
                      pag_gen.fu_obt_cotizacion(cc.cod_moneda, p_fec_actual)) *
               nvl(capital, 0) monto
          from ah_cta_certificados cc, ge_cta_clientes ct, ge_clientes cl
         where cc.est_batch NOT IN ('T', 'A', 'C', 'X', 'V', 'P')
           and sal_tot_batch > 0
           and cc.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and cc.fec_vencimiento > p_fec_actual
           and cc.cod_moneda <> v_moneda
           and ct.cod_persona = cl.cod_persona
           and (cc.fec_vencimiento - cc.fec_apertura) between 91 and 180
           and nvl(cc.sal_ret_batch, 0) = 0
         order by 1, 2;
    BEGIN

      --* Primero iserto todos los registros con monto y cantidad 0   < 90 DIAS
      v_concepto  := 'DEPOSITOS A PLAZO FIJO';
      v_secuencia := 4;
      v_plazo     := 4;
      v_moneda    := pag_gen.fu_obt_mon_local;

      LP_INS_SB_ESTRATIFIC(p_fec_actual, v_secuencia, v_concepto, v_plazo);

      --* TAMBIEN iserto todos los registros con monto y cantidad 0   PARA > 90 DIAS
      v_concepto  := 'DEPOSITOS A PLAZO FIJO';
      v_secuencia := 5;
      v_plazo     := 5;

      LP_INS_SB_ESTRATIFIC(p_fec_actual, v_secuencia, v_concepto, v_plazo);

      --* ahora voy a actualizar con los datos del cursor
      for reg in c_cta_cte loop
        if reg.lugar = 'MEN90' then
          v_concepto  := 'DEPOSITOS A PLAZO FIJO';
          v_secuencia := 4;
          v_plazo     := 4;
        else
          v_concepto  := 'DEPOSITOS A PLAZO FIJO';
          v_secuencia := 5;
          v_plazo     := 5;
        end if;
        tmen1 := 0;
        tmen2 := 0;
        tmen3 := 0;
        tmen4 := 0;
        tmen5 := 0;
        tmen6 := 0;
        if reg.rmen1 > 0 then
          tmen1 := 1;
        end if;
        if reg.rmen2 > 0 then
          tmen2 := 1;
        end if;
        if reg.rmen3 > 0 then
          tmen3 := 1;
        end if;
        if reg.rmen4 > 0 then
          tmen4 := 1;
        end if;
        if reg.rmen5 > 0 then
          tmen5 := 1;
        end if;
        if reg.rmen6 > 0 then
          tmen6 := 1;
        end if;
        if tmen1 + tmen2 + tmen3 + tmen4 + tmen5 + tmen6 = 0 then
          tmen1 := 1;
        end if;

        LP_UPD_SB_ESTRATIFIC(p_fec_actual,
                             v_concepto,
                             v_secuencia,
                             reg.mone,
                             reg.sec_contable,
                             reg.rmen1,
                             tmen1,
                             reg.rmen2,
                             tmen2,
                             reg.rmen3,
                             tmen3,
                             reg.rmen4,
                             tmen4,
                             reg.rmen5,
                             tmen5,
                             reg.rmen6,
                             tmen6);
      end loop;
      For reg in detalle loop
        if reg.lugar = 'MEN90' then
          v_concepto  := 'DEPOSITOS A PLAZO FIJO';
          v_secuencia := 4;
          v_plazo     := 4;
        else
          v_concepto  := 'DEPOSITOS A PLAZO FIJO';
          v_secuencia := 5;
          v_plazo     := 5;
        end if;
        insert into sb_estratificaciones_dep_det
          (FECHA,
           COD_MONEDA,
           COD_SEC_CONTABLE,
           NRO_CUENTA,
           MONTO,
           PLZ_HASTA,
           DESCRIPCION)
        values
          (p_fec_actual,
           REG.MONE,
           1,
           reg.nro_cuenta,
           reg.sal_tot_batch,
           v_plazo,
           V_CONCEPTO);
      End loop;
    END;
    /* Genera Estratificación para CDA menor o mayor a 360 días. */
    PROCEDURE LP_GEN_EST_CDA(P_FEC_ACTUAL IN DATE) IS

      V_CONCEPTO  VARCHAR2(60);
      V_SECUENCIA NUMBER(2);
      V_MONEDA    VARCHAR2(3);
      V_PLAZO     NUMBER(1);
      /*
      Tiene 4 select con union
      agrupa por sector(publico y no publico),moneda y rango
      1- certificado de deposito GS  - < 360 dias
      2- certificado de deposito GS  - > 360 dias
      3- certificado de deposito USS  - < 360 dias
      4- certificado de deposito USS - > 360 dias

      */
      tmen1 number(8);
      tmen2 number(8);
      tmen3 number(8);
      tmen4 number(8);
      tmen5 number(8);
      tmen6 number(8);
      --* GS - CDA x SECTOR  < 360 dias
      cursor c_cta_cte is
        select decode(cl.cod_sec_contable, 'P', 'P', 'I', 'P', 'X') sec_contable,
               decode(cc.cod_moneda, v_moneda, v_moneda, 'X') mone,
               'MEN360' lugar,
               --* suma monto
               sum(case
                     when nvl(sal_tot_batch, 0) <= v_rango1 then
                      nvl(capital, 0)
                     else
                      0
                   end) rmen1,
               sum(case
                     when nvl(sal_tot_batch, 0) between (v_rango1 + 1) and
                          v_rango2 then
                      nvl(capital, 0)
                     else
                      0
                   end) rmen2,
               sum(case
                     when nvl(sal_tot_batch, 0) between (v_rango2 + 1) and
                          v_rango3 then
                      nvl(capital, 0)
                     else
                      0
                   end) rmen3,
               sum(case
                     when nvl(sal_tot_batch, 0) between (v_rango3 + 1) and
                          v_rango4 then
                      nvl(capital, 0)
                     else
                      0
                   end) rmen4,
               sum(case
                     when nvl(sal_tot_batch, 0) between (v_rango4 + 1) and
                          v_rango5 then
                      nvl(capital, 0)
                     else
                      0
                   end) rmen5,
               sum(case
                     when nvl(sal_tot_batch, 0) > v_rango6 then
                      nvl(capital, 0)
                     else
                      0
                   end) rmen6,
               --* cuenta
               sum(case
                     when nvl(sal_tot_batch, 0) <= v_rango1 then
                      1
                     else
                      0
                   end) tmen1,
               sum(case
                     when nvl(sal_tot_batch, 0) between (v_rango1 + 1) and
                          v_rango2 then
                      1
                     else
                      0
                   end) tmen2,
               sum(case
                     when nvl(sal_tot_batch, 0) between (v_rango2 + 1) and
                          v_rango3 then
                      1
                     else
                      0
                   end) tmen3,
               sum(case
                     when nvl(sal_tot_batch, 0) between (v_rango3 + 1) and
                          v_rango4 then
                      1
                     else
                      0
                   end) tmen4,
               sum(case
                     when nvl(sal_tot_batch, 0) between (v_rango4 + 1) and
                          v_rango5 then
                      1
                     else
                      0
                   end) tmen5,
               sum(case
                     when nvl(sal_tot_batch, 0) > v_rango6 then
                      1
                     else
                      0
                   end) tmen6
          from ah_cta_certificados cc, ge_cta_clientes ct, ge_clientes cl
         where cc.est_batch NOT IN ('T', 'A', 'C', 'X', 'V', 'P')
           and sal_tot_batch > 0
           and cc.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and cc.cod_moneda = v_moneda
           and ct.cod_persona = cl.cod_persona
           and cc.fec_vencimiento > p_fec_actual
           and (cc.fec_vencimiento - cc.fec_apertura) between 181 and 365
           and nvl(cc.sal_ret_batch, 0) = 0
         group by decode(cl.cod_sec_contable, 'P', 'P', 'I', 'P', 'X'),
                  decode(cc.cod_moneda, v_moneda, v_moneda, 'X')
        union -- GS y > a 360 dias
        select decode(cl.cod_sec_contable, 'P', 'P', 'I', 'P', 'X') sec_contable,
               decode(cc.cod_moneda, v_moneda, v_moneda, 'X') mone,
               'MAY360' lugar,
               --* suma monto
               sum(case
                     when nvl(sal_tot_batch, 0) <= v_rango1 then
                      nvl(capital, 0)
                     else
                      0
                   end) rmen1,
               sum(case
                     when nvl(sal_tot_batch, 0) between (v_rango1 + 1) and
                          v_rango2 then
                      nvl(capital, 0)
                     else
                      0
                   end) rmen2,
               sum(case
                     when nvl(sal_tot_batch, 0) between (v_rango2 + 1) and
                          v_rango3 then
                      nvl(capital, 0)
                     else
                      0
                   end) rmen3,
               sum(case
                     when nvl(sal_tot_batch, 0) between (v_rango3 + 1) and
                          v_rango4 then
                      nvl(capital, 0)
                     else
                      0
                   end) rmen4,
               sum(case
                     when nvl(sal_tot_batch, 0) between (v_rango4 + 1) and
                          v_rango5 then
                      nvl(capital, 0)
                     else
                      0
                   end) rmen5,
               sum(case
                     when nvl(sal_tot_batch, 0) > v_rango6 then
                      nvl(capital, 0)
                     else
                      0
                   end) rmen6,
               --* cuenta
               sum(case
                     when nvl(sal_tot_batch, 0) <= v_rango1 then
                      1
                     else
                      0
                   end) tmen1,
               sum(case
                     when nvl(sal_tot_batch, 0) between (v_rango1 + 1) and
                          v_rango2 then
                      1
                     else
                      0
                   end) tmen2,
               sum(case
                     when nvl(sal_tot_batch, 0) between (v_rango2 + 1) and
                          v_rango3 then
                      1
                     else
                      0
                   end) tmen3,
               sum(case
                     when nvl(sal_tot_batch, 0) between (v_rango3 + 1) and
                          v_rango4 then
                      1
                     else
                      0
                   end) tmen4,
               sum(case
                     when nvl(sal_tot_batch, 0) between (v_rango4 + 1) and
                          v_rango5 then
                      1
                     else
                      0
                   end) tmen5,
               sum(case
                     when nvl(sal_tot_batch, 0) > v_rango6 then
                      1
                     else
                      0
                   end) tmen6
          from ah_cta_certificados cc, ge_cta_clientes ct, ge_clientes cl
         where cc.est_batch NOT IN ('T', 'A', 'C', 'X', 'V', 'P')
           and sal_tot_batch > 0
           and cc.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and cc.cod_moneda = v_moneda
           and ct.cod_persona = cl.cod_persona
           and cc.fec_vencimiento > p_fec_actual
           and (cc.fec_vencimiento - cc.fec_apertura) > 365
           and nvl(cc.sal_ret_batch, 0) = 0
         group by decode(cl.cod_sec_contable, 'P', 'P', 'I', 'P', 'X'),
                  decode(cc.cod_moneda, v_moneda, v_moneda, 'X')
        union --- DOLARES y < a 360 DIAS
        select decode(cl.cod_sec_contable, 'P', 'P', 'I', 'P', 'X') sec_contable,
               decode(cc.cod_moneda, v_moneda, v_moneda, 'X') mone,
               'MEN360' lugar,
               --* suma monto
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            P_FEC_ACTUAL)) *
                          nvl(sal_tot_batch, 0)) <= v_rango1 then
                      decode(cc.cod_moneda,
                             v_mon_fuerte,
                             v_cot_fuerte,
                             pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                       P_FEC_ACTUAL)) *
                      (nvl(capital, 0))
                     else
                      0
                   end) rmen1,
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            P_FEC_ACTUAL)) *
                          nvl(sal_tot_batch, 0)) between (v_rango1 + 1) and
                          v_rango2 then
                      decode(cc.cod_moneda,
                             v_mon_fuerte,
                             v_cot_fuerte,
                             pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                       P_FEC_ACTUAL)) *
                      (nvl(capital, 0))
                     else
                      0
                   end) rmen2,
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            P_FEC_ACTUAL)) *
                          nvl(sal_tot_batch, 0)) between (v_rango2 + 1) and
                          v_rango3 then
                      decode(cc.cod_moneda,
                             v_mon_fuerte,
                             v_cot_fuerte,
                             pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                       P_FEC_ACTUAL)) *
                      (nvl(capital, 0))
                     else
                      0
                   end) rmen3,
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            P_FEC_ACTUAL)) *
                          nvl(sal_tot_batch, 0)) between (v_rango3 + 1) and
                          v_rango4 then
                      decode(cc.cod_moneda,
                             v_mon_fuerte,
                             v_cot_fuerte,
                             pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                       P_FEC_ACTUAL)) *
                      (nvl(capital, 0))
                     else
                      0
                   end) rmen4,
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            P_FEC_ACTUAL)) *
                          nvl(sal_tot_batch, 0)) between (v_rango4 + 1) and
                          v_rango5 then
                      decode(cc.cod_moneda,
                             v_mon_fuerte,
                             v_cot_fuerte,
                             pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                       P_FEC_ACTUAL)) *
                      (nvl(capital, 0))
                     else
                      0
                   end) rmen5,
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            P_FEC_ACTUAL)) *
                          nvl(sal_tot_batch, 0)) > v_rango6 then
                      decode(cc.cod_moneda,
                             v_mon_fuerte,
                             v_cot_fuerte,
                             pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                       P_FEC_ACTUAL)) *
                      (nvl(capital, 0))
                     else
                      0
                   end) rmen6,
               --* cuenta
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            P_FEC_ACTUAL)) *
                          nvl(sal_tot_batch, 0)) <= v_rango1 then
                      1
                     else
                      0
                   end) tmen1,
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            P_FEC_ACTUAL)) *
                          nvl(sal_tot_batch, 0)) between (v_rango1 + 1) and
                          v_rango2 then
                      1
                     else
                      0
                   end) tmen2,
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            P_FEC_ACTUAL)) *
                          nvl(sal_tot_batch, 0)) between (v_rango2 + 1) and
                          v_rango3 then
                      1
                     else
                      0
                   end) tmen3,
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            P_FEC_ACTUAL)) *
                          nvl(sal_tot_batch, 0)) between (v_rango3 + 1) and
                          v_rango4 then
                      1
                     else
                      0
                   end) tmen4,
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            P_FEC_ACTUAL)) *
                          nvl(sal_tot_batch, 0)) between (v_rango4 + 1) and
                          v_rango5 then
                      1
                     else
                      0
                   end) tmen5,
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            P_FEC_ACTUAL)) *
                          nvl(sal_tot_batch, 0)) > v_rango6 then
                      1
                     else
                      0
                   end) tmen6
          from ah_cta_certificados cc, ge_cta_clientes ct, ge_clientes cl
         where cc.est_batch NOT IN ('T', 'A', 'C', 'X', 'V', 'P')
           and sal_tot_batch > 0
           and cc.fec_vencimiento > p_fec_actual
           and cc.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and cc.cod_moneda <> v_moneda
           and ct.cod_persona = cl.cod_persona
           and (cc.fec_vencimiento - cc.fec_apertura) between 181 and 365
           and nvl(cc.sal_ret_batch, 0) = 0
         group by decode(cl.cod_sec_contable, 'P', 'P', 'I', 'P', 'X'),
                  decode(cc.cod_moneda, v_moneda, v_moneda, 'X')
        union -- DOLARES y >  a 360 dias
        select decode(cl.cod_sec_contable, 'P', 'P', 'I', 'P', 'X') sec_contable,
               decode(cc.cod_moneda, v_moneda, v_moneda, 'X') mone,
               'MAY360' lugar,
               --* suma monto
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            P_FEC_ACTUAL)) *
                          nvl(sal_tot_batch, 0)) <= v_rango1 then
                      decode(cc.cod_moneda,
                             v_mon_fuerte,
                             v_cot_fuerte,
                             pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                       P_FEC_ACTUAL)) *
                      (nvl(capital, 0))
                     else
                      0
                   end) rmen1,
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            P_FEC_ACTUAL)) *
                          nvl(sal_tot_batch, 0)) between (v_rango1 + 1) and
                          v_rango2 then
                      decode(cc.cod_moneda,
                             v_mon_fuerte,
                             v_cot_fuerte,
                             pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                       P_FEC_ACTUAL)) *
                      (nvl(capital, 0))
                     else
                      0
                   end) rmen2,
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            P_FEC_ACTUAL)) *
                          nvl(sal_tot_batch, 0)) between (v_rango2 + 1) and
                          v_rango3 then
                      decode(cc.cod_moneda,
                             v_mon_fuerte,
                             v_cot_fuerte,
                             pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                       P_FEC_ACTUAL)) *
                      (nvl(capital, 0))
                     else
                      0
                   end) rmen3,
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            P_FEC_ACTUAL)) *
                          nvl(sal_tot_batch, 0)) between (v_rango3 + 1) and
                          v_rango4 then
                      decode(cc.cod_moneda,
                             v_mon_fuerte,
                             v_cot_fuerte,
                             pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                       P_FEC_ACTUAL)) *
                      (nvl(capital, 0))
                     else
                      0
                   end) rmen4,
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            P_FEC_ACTUAL)) *
                          nvl(sal_tot_batch, 0)) between (v_rango4 + 1) and
                          v_rango5 then
                      decode(cc.cod_moneda,
                             v_mon_fuerte,
                             v_cot_fuerte,
                             pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                       P_FEC_ACTUAL)) *
                      (nvl(capital, 0))
                     else
                      0
                   end) rmen5,
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            P_FEC_ACTUAL)) *
                          nvl(sal_tot_batch, 0)) > v_rango6 then
                      decode(cc.cod_moneda,
                             v_mon_fuerte,
                             v_cot_fuerte,
                             pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                       P_FEC_ACTUAL)) *
                      (nvl(capital, 0))
                     else
                      0
                   end) rmen6,
               --* cuenta
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            P_FEC_ACTUAL)) *
                          nvl(sal_tot_batch, 0)) <= v_rango1 then
                      1
                     else
                      0
                   end) tmen1,
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            P_FEC_ACTUAL)) *
                          nvl(sal_tot_batch, 0)) between (v_rango1 + 1) and
                          v_rango2 then
                      1
                     else
                      0
                   end) tmen2,
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            P_FEC_ACTUAL)) *
                          nvl(sal_tot_batch, 0)) between (v_rango2 + 1) and
                          v_rango3 then
                      1
                     else
                      0
                   end) tmen3,
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            P_FEC_ACTUAL)) *
                          nvl(sal_tot_batch, 0)) between (v_rango3 + 1) and
                          v_rango4 then
                      1
                     else
                      0
                   end) tmen4,
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            P_FEC_ACTUAL)) *
                          nvl(sal_tot_batch, 0)) between (v_rango4 + 1) and
                          v_rango5 then
                      1
                     else
                      0
                   end) tmen5,
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            P_FEC_ACTUAL)) *
                          nvl(sal_tot_batch, 0)) > v_rango6 then
                      1
                     else
                      0
                   end) tmen6
          from ah_cta_certificados cc, ge_cta_clientes ct, ge_clientes cl
         where cc.est_batch NOT IN ('T', 'A', 'C', 'X', 'V', 'P')
           and sal_tot_batch > 0
           and cc.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and cc.fec_vencimiento > p_fec_actual
           and cc.cod_moneda <> v_moneda
           and ct.cod_persona = cl.cod_persona
           and (cc.fec_vencimiento - cc.fec_apertura) > 365
           and nvl(cc.sal_ret_batch, 0) = 0
         group by decode(cl.cod_sec_contable, 'P', 'P', 'I', 'P', 'X'),
                  decode(cc.cod_moneda, v_moneda, v_moneda, 'X')
         order by 1, 2;

      Cursor detalle is
        select decode(cl.cod_sec_contable, 'P', 'P', 'I', 'P', 'X') sec_contable,
               decode(cc.cod_moneda, v_moneda, v_moneda, 'X') mone,
               cc.nro_cuenta,
               'MEN360' lugar,
               capital sal_tot_batch
          from ah_cta_certificados cc, ge_cta_clientes ct, ge_clientes cl
         where cc.est_batch NOT IN ('T', 'A', 'C', 'X', 'V', 'P')
           and sal_tot_batch > 0
           and cc.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and cc.fec_vencimiento > p_fec_actual
           and cc.cod_moneda = v_moneda
           and ct.cod_persona = cl.cod_persona
           and (cc.fec_vencimiento - cc.fec_apertura) between 181 and 365
           and nvl(cc.sal_ret_batch, 0) = 0
        union -- GS y > a 360 dias
        select decode(cl.cod_sec_contable, 'P', 'P', 'I', 'P', 'X') sec_contable,
               decode(cc.cod_moneda, v_moneda, v_moneda, 'X') mone,
               cc.nro_cuenta,
               'MAY360' lugar,
               capital
          from ah_cta_certificados cc, ge_cta_clientes ct, ge_clientes cl
         where cc.est_batch NOT IN ('T', 'A', 'C', 'X', 'V', 'P')
           and sal_tot_batch > 0
           and cc.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and cc.fec_vencimiento > p_fec_actual
           and cc.cod_moneda = v_moneda
           and ct.cod_persona = cl.cod_persona
           and (cc.fec_vencimiento - cc.fec_apertura) > 365
           and nvl(cc.sal_ret_batch, 0) = 0
        union --- DOLARES y < a 360 DIAS
        select decode(cl.cod_sec_contable, 'P', 'P', 'I', 'P', 'X') sec_contable,
               decode(cc.cod_moneda, v_moneda, v_moneda, 'X') mone,
               cc.nro_cuenta,
               'MEN360' lugar,
               decode(cc.cod_moneda,
                      v_mon_fuerte,
                      v_cot_fuerte,
                      pag_gen.fu_obt_cotizacion(cc.cod_moneda, P_FEC_ACTUAL)) *
               capital monto
          from ah_cta_certificados cc, ge_cta_clientes ct, ge_clientes cl
         where cc.est_batch NOT IN ('T', 'A', 'C', 'X', 'V', 'P')
           and sal_tot_batch > 0
           and cc.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and cc.fec_vencimiento > p_fec_actual
           and cc.cod_moneda <> v_moneda
           and ct.cod_persona = cl.cod_persona
           and (cc.fec_vencimiento - cc.fec_apertura) between 181 and 365
           and nvl(cc.sal_ret_batch, 0) = 0
        union -- DOLARES y >  a 360 dias
        select decode(cl.cod_sec_contable, 'P', 'P', 'I', 'P', 'X') sec_contable,
               decode(cc.cod_moneda, v_moneda, v_moneda, 'X') mone,
               cc.nro_cuenta,
               'MAY360' lugar,
               decode(cc.cod_moneda,
                      v_mon_fuerte,
                      v_cot_fuerte,
                      pag_gen.fu_obt_cotizacion(cc.cod_moneda, P_FEC_ACTUAL)) *
               capital monto
        --* suma monto
          from ah_cta_certificados cc, ge_cta_clientes ct, ge_clientes cl
         where cc.est_batch NOT IN ('T', 'A', 'C', 'X', 'V', 'P')
           and sal_tot_batch > 0
           and cc.fec_vencimiento > p_fec_actual
           and cc.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and cc.cod_moneda <> v_moneda
           and ct.cod_persona = cl.cod_persona
           and (cc.fec_vencimiento - cc.fec_apertura) > 365
           and nvl(cc.sal_ret_batch, 0) = 0
         order by 1, 2;

    BEGIN
      --* Primero inserto todos los registros con monto y cantidad 0   < 360 DIAS
      v_concepto  := 'CERTIFICADOS DE DEPOSITOS';
      v_secuencia := 6;
      v_plazo     := 6;
      v_moneda    := pag_gen.fu_obt_mon_local;

      LP_INS_SB_ESTRATIFIC(p_fec_actual, v_secuencia, v_concepto, v_plazo);

      --* TAMBIEN inserto todos los registros con monto y cantidad 0   > 360 DIAS
      v_concepto  := 'CERTIFICADOS DE DEPOSITOS';
      v_secuencia := 7;
      v_plazo     := 7;

      LP_INS_SB_ESTRATIFIC(p_fec_actual, v_secuencia, v_concepto, v_plazo);

      --* ahora voy a actualizar con los datos del cursor < y > a 360 dias
      for reg in c_cta_cte loop
        if reg.lugar = 'MAY360' then
          v_concepto  := 'CERTIFICADOS DE DEPOSITOS';
          v_secuencia := 7;
          v_plazo     := 7;
        else
          ---- MENOR A 360
          v_concepto  := 'CERTIFICADOS DE DEPOSITOS';
          v_secuencia := 6;
          v_plazo     := 6;
        end if;
        tmen1 := 0;
        tmen2 := 0;
        tmen3 := 0;
        tmen4 := 0;
        tmen5 := 0;
        tmen6 := 0;
        if reg.rmen1 > 0 then
          tmen1 := 1;
        end if;
        if reg.rmen2 > 0 then
          tmen2 := 1;
        end if;
        if reg.rmen3 > 0 then
          tmen3 := 1;
        end if;
        if reg.rmen4 > 0 then
          tmen4 := 1;
        end if;
        if reg.rmen5 > 0 then
          tmen5 := 1;
        end if;
        if reg.rmen6 > 0 then
          tmen6 := 1;
        end if;
        if tmen1 + tmen2 + tmen3 + tmen4 + tmen5 + tmen6 = 0 then
          tmen1 := 1;
        end if;

        LP_UPD_SB_ESTRATIFIC(p_fec_actual,
                             v_concepto,
                             v_secuencia,
                             reg.mone,
                             reg.sec_contable,
                             reg.rmen1,
                             tmen1,
                             reg.rmen2,
                             tmen2,
                             reg.rmen3,
                             tmen3,
                             reg.rmen4,
                             tmen4,
                             reg.rmen5,
                             tmen5,
                             reg.rmen6,
                             tmen6);
      end loop;
      For reg in detalle loop
        if reg.lugar = 'MAY360' then
          v_concepto  := 'CERTIFICADOS DE DEPOSITOS';
          v_secuencia := 7;
          v_plazo     := 7;
        else
          ---- MENOR A 360
          v_concepto  := 'CERTIFICADOS DE DEPOSITOS';
          v_secuencia := 6;
          v_plazo     := 6;
        end if;
        insert into sb_estratificaciones_dep_det
          (FECHA,
           COD_MONEDA,
           COD_SEC_CONTABLE,
           NRO_CUENTA,
           MONTO,
           PLZ_HASTA,
           DESCRIPCION)
        values
          (p_fec_actual,
           REG.MONE,
           1,
           reg.nro_cuenta,
           reg.sal_tot_batch,
           v_plazo,
           V_CONCEPTO);
      End loop;

    END;
    /* Actualiza los registros insertados por cada tipo */
    PROCEDURE LP_UPD_SB_ESTRATIFIC(P_FECHA           IN DATE,
                                   P_CONCEPTO        IN SB_ESTRATIFICACIONES_DEP.CONCEPTO%TYPE,
                                   P_SECUENCIA       IN SB_ESTRATIFICACIONES_DEP.SECUENCIA%TYPE,
                                   P_MONEDA          IN SB_ESTRATIFICACIONES_DEP.COD_MONEDA%TYPE,
                                   P_SECTOR_CONTABLE IN SB_ESTRATIFICACIONES_DEP.COD_SEC_CONTABLE%TYPE,
                                   P_MONTO1          IN SB_ESTRATIFICACIONES_DEP.MONTO%TYPE,
                                   P_CANT1           IN SB_ESTRATIFICACIONES_DEP.CANTIDAD%TYPE,
                                   P_MONTO2          IN SB_ESTRATIFICACIONES_DEP.MONTO%TYPE,
                                   P_CANT2           IN SB_ESTRATIFICACIONES_DEP.CANTIDAD%TYPE,
                                   P_MONTO3          IN SB_ESTRATIFICACIONES_DEP.MONTO%TYPE,
                                   P_CANT3           IN SB_ESTRATIFICACIONES_DEP.CANTIDAD%TYPE,
                                   P_MONTO4          IN SB_ESTRATIFICACIONES_DEP.MONTO%TYPE,
                                   P_CANT4           IN SB_ESTRATIFICACIONES_DEP.CANTIDAD%TYPE,
                                   P_MONTO5          IN SB_ESTRATIFICACIONES_DEP.MONTO%TYPE,
                                   P_CANT5           IN SB_ESTRATIFICACIONES_DEP.CANTIDAD%TYPE,
                                   P_MONTO6          IN SB_ESTRATIFICACIONES_DEP.MONTO%TYPE,
                                   P_CANT6           IN SB_ESTRATIFICACIONES_DEP.CANTIDAD%TYPE) IS
    BEGIN
      begin
        update sb_estratificaciones_dep
           set monto    = nvl(monto, 0) + nvl(p_monto1, 0),
               cantidad = nvl(cantidad, 0) + nvl(p_cant1, 0)
         where fecha = p_fecha
           and cod_moneda = p_moneda
           and cod_Sec_contable = p_sector_contable
           and mto_hasta = v_rango1
           and secuencia = p_secuencia
           and concepto = p_concepto;
      exception
        when others then
          raise_application_error(-20020,
                                  'p_monto1 ' || p_monto1 || ' ' ||
                                  'p_cant1 ' || p_cant1 || ' ' || sqlerrm);
      end;

      begin
        update sb_estratificaciones_dep
           set monto    = nvl(monto, 0) + nvl(p_monto2, 0),
               cantidad = nvl(cantidad, 0) + nvl(p_cant2, 0)
         where fecha = p_fecha
           and cod_moneda = p_moneda
           and cod_Sec_contable = p_sector_contable
           and mto_hasta = v_rango2
           and secuencia = p_secuencia
           and concepto = p_concepto;
      exception
        when others then
          raise_application_error(-20020,
                                  'p_monto2 ' || p_monto2 || ' ' ||
                                  'p_cant2 ' || p_cant2 || ' ' || sqlerrm);
      end;

      begin
        update sb_estratificaciones_dep
           set monto    = nvl(monto, 0) + nvl(p_monto3, 0),
               cantidad = nvl(cantidad, 0) + nvl(p_cant3, 0)
         where fecha = p_fecha
           and cod_moneda = p_moneda
           and cod_Sec_contable = p_sector_contable
           and mto_hasta = v_rango3
           and secuencia = p_secuencia
           and concepto = p_concepto;
      exception
        when others then
          raise_application_error(-20020,
                                  'p_monto3 ' || p_monto3 || ' ' ||
                                  'p_cant3 ' || p_cant3 || ' ' || sqlerrm);
      end;

      begin
        update sb_estratificaciones_dep
           set monto    = nvl(monto, 0) + nvl(p_monto4, 0),
               cantidad = nvl(cantidad, 0) + nvl(p_cant4, 0)
         where fecha = p_fecha
           and cod_moneda = p_moneda
           and cod_Sec_contable = p_sector_contable
           and mto_hasta = v_rango4
           and secuencia = p_secuencia
           and concepto = p_concepto;
      exception
        when others then
          raise_application_error(-20020,
                                  'p_monto4 ' || p_monto4 || ' ' ||
                                  'p_cant4 ' || p_cant4 || ' ' || sqlerrm);
      end;

      begin
        update sb_estratificaciones_dep
           set monto    = nvl(monto, 0) + nvl(p_monto5, 0),
               cantidad = nvl(cantidad, 0) + nvl(p_cant5, 0)
         where fecha = p_fecha
           and cod_moneda = p_moneda
           and cod_Sec_contable = p_sector_contable
           and mto_hasta = v_rango5
           and secuencia = p_secuencia
           and concepto = p_concepto;
      exception
        when others then
          raise_application_error(-20020,
                                  'p_monto5 ' || p_monto5 || ' ' ||
                                  'p_cant5 ' || p_cant5 || ' ' || sqlerrm);
      end;

      begin
        update sb_estratificaciones_dep
           set monto    = nvl(monto, 0) + nvl(p_monto6, 0),
               cantidad = nvl(cantidad, 0) + nvl(p_cant6, 0)
         where fecha = p_fecha
           and cod_moneda = p_moneda
           and cod_Sec_contable = p_sector_contable
           and mto_hasta = v_rango6
           and secuencia = p_secuencia
           and concepto = p_concepto;
      exception
        when others then
          raise_application_error(-20020,
                                  'p_monto6 ' || p_monto6 || ' ' ||
                                  'p_cant6 ' || p_cant6 || ' ' || sqlerrm);
      end;
    EXCEPTION
      WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20020,
                                'ERROR al Actualizar SB_ESTRATIFICACIONES_DEP ' ||
                                sqlerrm);
    END;

    --Procedimiento que incluye las cuentas de bancos oficiales y cuentas de cheque gerencia
    PROCEDURE LP_GEN_EST_CTA_BANCARIA(P_FEC_ACTUAL IN DATE) IS

      V_SECUENCIA SB_ESTRATIFICACIONES_DEP.SECUENCIA%TYPE;
      V_MONEDA    VARCHAR2(3);
      V_PLAZO     NUMBER(1);
      V_CONCEPTO  SB_ESTRATIFICACIONES_DEP.CONCEPTO%TYPE;
      /*
      Tiene cuatro select con union agrupa por sector(publico y no publico),moneda y rango
      1- vista GS
      2- vista USS
      */
      tmen1 number(8);
      tmen2 number(8);
      tmen3 number(8);
      tmen4 number(8);
      tmen5 number(8);
      tmen6 number(8);
      --* GS - VISTA - X SECTOR
      CURSOR c_vista IS
        select decode(cl.cod_sec_contable, 'P', 'P', 'I', 'P', 'X') sec_contable,
               decode(cc.cod_moneda, v_moneda, v_moneda, 'X') mone,
               cl.cod_persona,
               --* suma monto
               sum(case
                     when nvl(sal_tot_batch, 0) <= v_rango1 then
                      nvl(sal_tot_batch, 0)
                     else
                      0
                   end) rmen1,
               sum(case
                     when nvl(sal_tot_batch, 0) between (v_rango1 + 1) and
                          v_rango2 then
                      nvl(sal_tot_batch, 0)
                     else
                      0
                   end) rmen2,
               sum(case
                     when nvl(sal_tot_batch, 0) between (v_rango2 + 1) and
                          v_rango3 then
                      nvl(sal_tot_batch, 0)
                     else
                      0
                   end) rmen3,
               sum(case
                     when nvl(sal_tot_batch, 0) between (v_rango3 + 1) and
                          v_rango4 then
                      nvl(sal_tot_batch, 0)
                     else
                      0
                   end) rmen4,
               sum(case
                     when nvl(sal_tot_batch, 0) between (v_rango4 + 1) and
                          v_rango5 then
                      nvl(sal_tot_batch, 0)
                     else
                      0
                   end) rmen5,
               sum(case
                     when nvl(sal_tot_batch, 0) > v_rango6 then
                      nvl(sal_tot_batch, 0)
                     else
                      0
                   end) rmen6,
               --* cuenta
               sum(case
                     when nvl(sal_tot_batch, 0) <= v_rango1 then
                      1
                     else
                      0
                   end) tmen1,
               sum(case
                     when nvl(sal_tot_batch, 0) between (v_rango1 + 1) and
                          v_rango2 then
                      1
                     else
                      0
                   end) tmen2,
               sum(case
                     when nvl(sal_tot_batch, 0) between (v_rango2 + 1) and
                          v_rango3 then
                      1
                     else
                      0
                   end) tmen3,
               sum(case
                     when nvl(sal_tot_batch, 0) between (v_rango3 + 1) and
                          v_rango4 then
                      1
                     else
                      0
                   end) tmen4,
               sum(case
                     when nvl(sal_tot_batch, 0) between (v_rango4 + 1) and
                          v_rango5 then
                      1
                     else
                      0
                   end) tmen5,
               sum(case
                     when nvl(sal_tot_batch, 0) > v_rango6 then
                      1
                     else
                      0
                   end) tmen6
          from cc_cta_bancarias cc, ge_cta_clientes ct, ge_clientes cl
         where cc.est_batch not in ('A', 'C', 'X')
           and cc.cod_modalidad = 44
           and cc.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and cc.cod_moneda = v_moneda
           and ct.cod_persona = cl.cod_persona
         group by decode(cl.cod_sec_contable, 'P', 'P', 'I', 'P', 'X'),
                  decode(cc.cod_moneda, v_moneda, v_moneda, 'X'),
                  cl.cod_persona
        union
        --* DOLARES - VISTA - X SECTOR
        select decode(cl.cod_sec_contable, 'P', 'P', 'I', 'P', 'X') sec_contable,
               decode(cc.cod_moneda, v_moneda, v_moneda, 'X') mone,
               cl.cod_persona,
               --* suma
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            p_fec_actual)) *
                          nvl(sal_tot_batch, 0)) <= v_rango1 then
                      decode(cc.cod_moneda,
                             v_mon_fuerte,
                             v_cot_fuerte,
                             pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                       p_fec_actual)) *
                      nvl(sal_tot_batch, 0)
                     else
                      0
                   end) rmen1,
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            p_fec_actual)) *
                          nvl(sal_tot_batch, 0)) between (v_rango1 + 1) and
                          v_rango2 then
                      decode(cc.cod_moneda,
                             v_mon_fuerte,
                             v_cot_fuerte,
                             pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                       p_fec_actual)) *
                      nvl(sal_tot_batch, 0)
                     else
                      0
                   end) rmen2,
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            p_fec_actual)) *
                          nvl(sal_tot_batch, 0)) between (v_rango2 + 1) and
                          v_rango3 then
                      decode(cc.cod_moneda,
                             v_mon_fuerte,
                             v_cot_fuerte,
                             pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                       p_fec_actual)) *
                      nvl(sal_tot_batch, 0)
                     else
                      0
                   end) rmen3,
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            p_fec_actual)) *
                          nvl(sal_tot_batch, 0)) between (v_rango3 + 1) and
                          v_rango4 then
                      decode(cc.cod_moneda,
                             v_mon_fuerte,
                             v_cot_fuerte,
                             pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                       p_fec_actual)) *
                      nvl(sal_tot_batch, 0)
                     else
                      0
                   end) rmen4,
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            p_fec_actual)) *
                          nvl(sal_tot_batch, 0)) between (v_rango4 + 1) and
                          v_rango5 then
                      decode(cc.cod_moneda,
                             v_mon_fuerte,
                             v_cot_fuerte,
                             pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                       p_fec_actual)) *
                      nvl(sal_tot_batch, 0)
                     else
                      0
                   end) rmen5,
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            p_fec_actual)) *
                          nvl(sal_tot_batch, 0)) > v_rango6 then
                      decode(cc.cod_moneda,
                             v_mon_fuerte,
                             v_cot_fuerte,
                             pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                       p_fec_actual)) *
                      nvl(sal_tot_batch, 0)
                     else
                      0
                   end) rmen6,
               --* cuenta
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            p_fec_actual)) *
                          nvl(sal_tot_batch, 0)) <= v_rango1 then
                      1
                     else
                      0
                   end) tmen1,
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            p_fec_actual)) *
                          nvl(sal_tot_batch, 0)) between (v_rango1 + 1) and
                          v_rango2 then
                      1
                     else
                      0
                   end) tmen2,
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            p_fec_actual)) *
                          nvl(sal_tot_batch, 0)) between (v_rango2 + 1) and
                          v_rango3 then
                      1
                     else
                      0
                   end) tmen3,
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            p_fec_actual)) *
                          nvl(sal_tot_batch, 0)) between (v_rango3 + 1) and
                          v_rango4 then
                      1
                     else
                      0
                   end) tmen4,
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            p_fec_actual)) *
                          nvl(sal_tot_batch, 0)) between (v_rango4 + 1) and
                          v_rango5 then
                      1
                     else
                      0
                   end) tmen5,
               sum(case
                     when (decode(cc.cod_moneda,
                                  v_mon_fuerte,
                                  v_cot_fuerte,
                                  pag_gen.fu_obt_cotizacion(cc.cod_moneda,
                                                            p_fec_actual)) *
                          nvl(sal_tot_batch, 0)) > v_rango6 then
                      1
                     else
                      0
                   end) tmen6
          from cc_cta_bancarias cc, ge_cta_clientes ct, ge_clientes cl
         where cc.est_batch not in ('A', 'C', 'X')
           and cc.cod_modalidad = 44
           and cc.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and cc.cod_moneda <> v_moneda
           and ct.cod_persona = cl.cod_persona
         group by decode(cl.cod_sec_contable, 'P', 'P', 'I', 'P', 'X'),
                  decode(cc.cod_moneda, v_moneda, v_moneda, 'X'),
                  cl.cod_persona
         order by 1, 2;

      -- Para grabar el detalle
      Cursor detalle is
        select decode(cl.cod_sec_contable, 'P', 'P', 'I', 'P', 'X') sec_contable,
               decode(cc.cod_moneda, v_moneda, v_moneda, 'X') mone,
               cc.nro_cuenta,
               nvl(sal_tot_batch, 0) sal_tot_batch
          from cc_cta_bancarias cc, ge_cta_clientes ct, ge_clientes cl
         where cc.est_batch not in ('A', 'C', 'X')
           and cc.cod_modalidad = 44
           and cc.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and cc.cod_moneda = v_moneda
           and ct.cod_persona = cl.cod_persona
        union
        --* DOLARES - VISTA - X SECTOR
        select decode(cl.cod_sec_contable, 'P', 'P', 'I', 'P', 'X') sec_contable,
               decode(cc.cod_moneda, v_moneda, v_moneda, 'X') mone,
               cc.nro_cuenta,
               decode(cc.cod_moneda,
                      v_mon_fuerte,
                      v_cot_fuerte,
                      pag_gen.fu_obt_cotizacion(cc.cod_moneda, p_fec_actual)) *
               (nvl(sal_tot_batch, 0)) monto
          from cc_cta_bancarias cc, ge_cta_clientes ct, ge_clientes cl
         where cc.est_batch not in ('A', 'C', 'X')
           and cc.cod_modalidad = 44
           and cc.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and cc.cod_moneda <> v_moneda
           and ct.cod_persona = cl.cod_persona
         order by 1, 2;
    BEGIN
      --* Primero inserto todos los registros con monto y cantidad 0
      v_concepto  := 'CUENTAS BANCARIAS';
      v_secuencia := 1;
      v_plazo     := 1;
      v_moneda    := pag_gen.fu_obt_mon_local;

      LP_INS_SB_ESTRATIFIC(p_fec_actual, v_secuencia, v_concepto, v_plazo);

      --* ahora voy a actualizar con los datos del cursor
      For reg in c_vista loop
        tmen1 := 0;
        tmen2 := 0;
        tmen3 := 0;
        tmen4 := 0;
        tmen5 := 0;
        tmen6 := 0;
        if reg.rmen1 > 0 then
          tmen1 := 1;
        end if;
        if reg.rmen2 > 0 then
          tmen2 := 1;
        end if;
        if reg.rmen3 > 0 then
          tmen3 := 1;
        end if;
        if reg.rmen4 > 0 then
          tmen4 := 1;
        end if;
        if reg.rmen5 > 0 then
          tmen5 := 1;
        end if;
        if reg.rmen6 > 0 then
          tmen6 := 1;
        end if;
        if tmen1 + tmen2 + tmen3 + tmen4 + tmen5 + tmen6 = 0 then
          tmen1 := 1;
        end if;

        LP_UPD_SB_ESTRATIFIC(p_fec_actual,
                             v_concepto,
                             v_secuencia,
                             reg.mone,
                             reg.sec_contable,
                             reg.rmen1,
                             tmen1,
                             reg.rmen2,
                             tmen2,
                             reg.rmen3,
                             tmen3,
                             reg.rmen4,
                             tmen4,
                             reg.rmen5,
                             tmen5,
                             reg.rmen6,
                             tmen6);
      end loop;
      For reg in detalle loop
        insert into sb_estratificaciones_dep_det
          (FECHA,
           COD_MONEDA,
           COD_SEC_CONTABLE,
           NRO_CUENTA,
           MONTO,
           PLZ_HASTA,
           DESCRIPCION)
        values
          (p_fec_actual,
           reg.mone,
           1,
           reg.nro_cuenta,
           reg.sal_tot_batch,
           v_plazo,
           V_CONCEPTO);
      End loop;
    END;

  BEGIN
    v_fec_actual := pag_cal.fu_obt_fec_actual(3);
    v_mon_fuerte := pag_gen.fu_obt_mon_fuerte;
    v_cot_fuerte := pag_gen.fu_obt_cotizacion(v_mon_fuerte, V_FEC_ACTUAL);
    begin
      select sal_min_vigente into v_sal_min_vigente from pr_parametros;
    exception
      when others then
        raise_application_error(-20000,
                                'Error al recuperar pr_parametros.sal_min_vigente ' ||
                                sqlerrm);
    end;

    --Hasta 10 salarios minimos
    v_rango1 := v_sal_min_vigente * 10;
    --Mayor a 10 salarios minimos  hasta 75 salarios minimos
    v_rango2 := v_sal_min_vigente * 75;
    --Mayor a 75 salarios minimos  hasta 150 salarios minimos
    v_rango3 := v_sal_min_vigente * 150;
    --Mayor a 150 salarios minimos  hasta 250 salarios minimos
    v_rango4 := v_sal_min_vigente * 250;
    --Mayor a 250 salarios minimos  hasta 350 salarios minimos
    v_rango5 := v_sal_min_vigente * 350;
    --Mayor 350 salarios minimos
    v_rango6 := (v_sal_min_vigente * 350) + 1;

    DELETE FROM SB_ESTRATIFICACIONES_DEP WHERE FECHA = V_FEC_ACTUAL;
    DELETE FROM SB_ESTRATIFICACIONES_DEP_DET WHERE FECHA = V_FEC_ACTUAL;
    lp_gen_est_cta_cte(v_fec_actual);
    lp_gen_est_ah_vista(v_fec_actual);
    lp_gen_est_plz_fijo(v_fec_actual);
    lp_gen_est_cda(v_fec_actual);
    lp_gen_est_cta_bancaria(v_fec_actual);
  END;
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
  PROCEDURE PR_GEN_ANA_LIQ IS

    P_FEC_ACTUAL DATE;

    /* Calcula la liquidez para moneda extranjera */
    PROCEDURE LP_CAL_LIQ_MON_EXTR(P_FEC_ACTUAL IN DATE);
    /* Calcula la liquidez para moneda local */
    PROCEDURE LP_CAL_LIQ_MON_LOCAL(P_FEC_ACTUAL IN DATE);
    /* Inserta registro de liquidez */
    PROCEDURE LP_INS_REG_LIQUIDEZ(P_FEC_ACTUAL  IN DATE,
                                  P_DESCRIPCION IN VARCHAR2,
                                  P_MONEDA      IN VARCHAR2,
                                  P_NROCTA      IN VARCHAR2,
                                  P_MTODEV      IN NUMBER,
                                  P_MTOCAP      IN NUMBER,
                                  P_PLAZO       IN NUMBER,
                                  P_MTOPREV     IN NUMBER DEFAULT 0);
    /* Calcula la liquidez préstamos para moneda extranjera */
    PROCEDURE LP_CAL_LIQ_MONEXT_PR(P_FEC_ACTUAL IN DATE);
    /* Calcula la liquidez préstamos para moneda local */
    PROCEDURE LP_CAL_LIQ_MONLOC_PR(P_FEC_ACTUAL IN DATE);
    P_DESCRIPCION VARCHAR2(50);
    P_MONEDA      BA_MONEDAS.COD_MONEDA%TYPE;
    P_NROCTA      AH_CTA_VISTAS.NRO_CUENTA%TYPE;
    P_MTODEV      NUMBER(18, 2);
    P_MTOCAP      NUMBER(18, 2);
    P_PLAZO       NUMBER(7);
    /* Calcula la liquidez */

    /* Calcula la liquidez para moneda extranjera */
    PROCEDURE LP_CAL_LIQ_MON_EXTR(P_FEC_ACTUAL IN DATE) IS

      V_SAL_ACTUAL2  NUMBER(18, 2);
      V_SAL_ACTUAL1  NUMBER(18, 2);
      V_SAL_ACTUAL   NUMBER(18, 2);
      V_MEN_30_DIAS  NUMBER(18, 2);
      V_MEN_90_DIAS  NUMBER(18, 2);
      V_MEN_180_DIAS NUMBER(18, 2);
      V_MEN_1_ANO    NUMBER(18, 2);
      V_MEN_3_ANOS   NUMBER(18, 2);
      V_MAY_3_ANOS   NUMBER(18, 2);
      V_CUENTA       VARCHAR2(15);
      V_MONEDA       AH_CTA_CERTIFICADOS.COD_MONEDA%TYPE;
      -- MONEDA EXTRANJERA --
      --sector financiero
      Cursor fin is
        select ah.nro_cuenta,
               (nvl(decode(ah.est_cer_batch,
                           'V',
                           ah.sal_tot_batch,
                           'P',
                           ah.sal_tot_batch,
                           ah.sal_tot_batch - ah.capital),
                    0)) saldo
          from ah_cta_certificados ah, ge_cta_clientes ct, ge_clientes cl
         where ah.est_batch NOT IN ('T', 'A', 'C', 'X')
           and (est_cer_batch IN ('V', 'P') or sal_tot_batch > capital)
           and ah.cod_moneda = V_MONEDA
           and ah.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and ct.cod_persona = cl.cod_persona
           and cl.cod_sec_contable IN ('F', 'P', 'I') --- Financiero y Publico
              --agregado para quitar los retenidos--
           and nvl(ah.sal_ret_batch, 0) = 0;
      Cursor fin2 is
        select ah.nro_cuenta,
               nvl((ah.sal_tot_batch), 0) SALDO,
               nvl((nvl(decode(ah.fec_ult_capitalizacion,
                               p_fec_actual,
                               0,
                               pas_bcp.fu_obt_dev_av(ah.nro_cuenta,
                                                     P_FEC_ACTUAL)),
                        0)),
                   0) MTO_DEV
          from ah_cta_vistas ah, ge_cta_clientes ct, ge_clientes cl
         where ah.cod_moneda = V_MONEDA
           and ah.est_batch not in ('A', 'C') --Abierta y cancelada;
           and ah.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and ct.cod_persona = cl.cod_persona
           and cl.cod_sec_contable IN ('F', 'P', 'I'); --- Financiero y Publico

      -- Menores a 30 días
      Cursor Men30 is
        select ah.nro_cuenta,
               nvl((ah.capital), 0) saldo,
               nvl((nvl(pas_bcp.fu_obt_dev_cda(ah.nro_cuenta,
                                               ah.capital,
                                               ah.fec_apertura,
                                               P_FEC_ACTUAL),
                        0)),
                   0) MTO_DEV
          from ah_cta_certificados ah, ge_cta_clientes ct, ge_clientes cl
         where ah.fec_vencimiento - p_fec_actual <= 30
           and ah.est_cer_batch not in ('V', 'P')
           and ah.est_batch NOT IN ('T', 'A', 'C', 'X')
           and ah.cod_moneda = V_MONEDA
           and ah.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and ct.cod_persona = cl.cod_persona
           and cl.cod_sec_contable IN ('F', 'P', 'I') --- Financiero y Publico
              --agregado para quitar los retenidos--
           and nvl(ah.sal_ret_batch, 0) = 0;

      -- De 31 a 90 días
      Cursor A90 is
        select ah.nro_cuenta,
               nvl((ah.capital), 0) saldo,
               nvl((nvl(pas_bcp.fu_obt_dev_cda(ah.nro_cuenta,
                                               ah.capital,
                                               ah.fec_apertura,
                                               P_FEC_ACTUAL),
                        0)),
                   0) MTO_DEV
          from ah_cta_certificados ah, ge_cta_clientes ct, ge_clientes cl
         where ah.fec_vencimiento - p_fec_actual between 31 and 90
           and ah.est_cer_batch not in ('V', 'P')
           and ah.est_batch NOT IN ('T', 'A', 'C', 'X')
           and ah.cod_moneda = V_MONEDA
           and ah.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and ct.cod_persona = cl.cod_persona
           and cl.cod_sec_contable IN ('F', 'P', 'I') --- Financiero y Publico
              --agregado para quitar los retenidos--
           and nvl(ah.sal_ret_batch, 0) = 0;

      -- De 91 a 180 dias
      Cursor A180 is
        select ah.nro_cuenta,
               nvl((ah.capital), 0) saldo,
               nvl((nvl(pas_bcp.fu_obt_dev_cda(ah.nro_cuenta,
                                               ah.capital,
                                               ah.fec_apertura,
                                               P_FEC_ACTUAL),
                        0)),
                   0) MTO_DEV
          from ah_cta_certificados ah, ge_cta_clientes ct, ge_clientes cl
         where ah.fec_vencimiento - p_fec_actual between 91 and 180
           and ah.est_cer_batch not in ('V', 'P')
           and ah.est_batch NOT IN ('T', 'A', 'C', 'X')
           and ah.cod_moneda = V_MONEDA
           and ah.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and ct.cod_persona = cl.cod_persona
           and cl.cod_sec_contable IN ('F', 'P', 'I') --- Financiero y Publico
              --agregado para quitar los retenidos--
           and nvl(ah.sal_ret_batch, 0) = 0;

      -- De 181 a 365 dias
      Cursor A365 is
        select ah.nro_cuenta,
               nvl((ah.capital), 0) saldo,
               nvl((nvl(pas_bcp.fu_obt_dev_cda(ah.nro_cuenta,
                                               ah.capital,
                                               ah.fec_apertura,
                                               P_FEC_ACTUAL),
                        0)),
                   0) MTO_DEV
          from ah_cta_certificados ah, ge_cta_clientes ct, ge_clientes cl
         where ah.fec_vencimiento - p_fec_actual between 181 and 365
           and ah.est_cer_batch not in ('V', 'P')
           and ah.est_batch NOT IN ('T', 'A', 'C', 'X')
           and ah.cod_moneda = V_MONEDA
           and ah.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and ct.cod_persona = cl.cod_persona
           and cl.cod_sec_contable IN ('F', 'P', 'I') --- Financiero y Publico
              --agregado para quitar los retenidos--
           and nvl(ah.sal_ret_batch, 0) = 0;

      -- De 365 a 1095 dias(3 años)
      Cursor A1095 is
        select ah.nro_cuenta,
               nvl((ah.capital), 0) saldo,
               nvl((nvl(pas_bcp.fu_obt_dev_cda(ah.nro_cuenta,
                                               ah.capital,
                                               ah.fec_apertura,
                                               P_FEC_ACTUAL),
                        0)),
                   0) MTO_DEV
          from ah_cta_certificados ah, ge_cta_clientes ct, ge_clientes cl
         where ah.fec_vencimiento - p_fec_actual between 366 and 1095
           and ah.est_cer_batch not in ('V', 'P')
           and ah.est_batch NOT IN ('T', 'A', 'C', 'X')
           and ah.cod_moneda = V_MONEDA
           and ah.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and ct.cod_persona = cl.cod_persona
           and cl.cod_sec_contable IN ('F', 'P', 'I') --- Financiero y Publico
              --agregado para quitar los retenidos--
           and nvl(ah.sal_ret_batch, 0) = 0;

      -- Mayor 1095 dias(3 años)
      Cursor M1095 is
        select ah.nro_cuenta,
               nvl((ah.capital), 0) saldo,
               nvl((nvl(pas_bcp.fu_obt_dev_cda(ah.nro_cuenta,
                                               ah.capital,
                                               ah.fec_apertura,
                                               P_FEC_ACTUAL),
                        0)),
                   0) MTO_DEV
          from ah_cta_certificados ah, ge_cta_clientes ct, ge_clientes cl
         where ah.fec_vencimiento - p_fec_actual > 1095
           and ah.est_cer_batch not in ('V', 'P')
           and ah.est_batch NOT IN ('T', 'A', 'C', 'X')
           and ah.cod_moneda = V_MONEDA
           and ah.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and ct.cod_persona = cl.cod_persona
           and cl.cod_sec_contable IN ('F', 'P', 'I') --- Financiero y Publico
              --agregado para quitar los retenidos--
           and nvl(ah.sal_ret_batch, 0) = 0;

      --sector no financiero --
      Cursor nofin1 is
        select ah.nro_cuenta,
               (nvl((decode(ah.est_cer_batch,
                            'V',
                            ah.sal_tot_batch,
                            'P',
                            ah.sal_tot_batch,
                            ah.sal_tot_batch - ah.capital)),
                    0)) saldo
          from ah_cta_certificados ah, ge_cta_clientes ct, ge_clientes cl
         where ah.est_batch NOT IN ('T', 'A', 'C', 'X')
           and (est_cer_batch in ('V', 'P') or sal_tot_batch > capital)
           and ah.cod_moneda = V_MONEDA
           and ah.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and ct.cod_persona = cl.cod_persona
           and cl.cod_sec_contable = 'N'
              --agregado para quitar los retenidos--
           and nvl(ah.sal_ret_batch, 0) = 0;

      Cursor nofin2 is
        select ah.nro_cuenta,
               (nvl((ah.sal_tot_batch), 0)) saldo,
               nvl((nvl(decode(ah.fec_ult_capitalizacion,
                               p_fec_actual,
                               0,
                               pas_bcp.fu_obt_dev_av(ah.nro_cuenta,
                                                     P_FEC_ACTUAL)),
                        0)),
                   0) mto_dev
          from ah_cta_vistas ah, ge_cta_clientes ct, ge_clientes cl
         where ah.cod_moneda = V_MONEDA
           and ah.est_batch not in ('A', 'C') --Abierta y cancelada;
           and ah.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and ct.cod_persona = cl.cod_persona
           and cl.cod_sec_contable = 'N';

      -- Menores a 30 días
      Cursor nmen30 is
        select ah.nro_cuenta,
               (nvl((ah.capital), 0)) saldo,
               nvl((nvl(pas_bcp.fu_obt_dev_cda(ah.nro_cuenta,
                                               ah.capital,
                                               ah.fec_apertura,
                                               P_FEC_ACTUAL),
                        0)),
                   0) mto_dev
          from ah_cta_certificados ah, ge_cta_clientes ct, ge_clientes cl
         where ah.fec_vencimiento - p_fec_actual <= 30
           and ah.est_cer_batch not in ('V', 'P')
           and ah.est_batch NOT IN ('T', 'A', 'C', 'X')
           and ah.cod_moneda = V_MONEDA
           and ah.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and ct.cod_persona = cl.cod_persona
           and cl.cod_sec_contable = 'N'
              --agregado para quitar los retenidos--
           and nvl(ah.sal_ret_batch, 0) = 0;

      -- De 31 a 90 días
      Cursor na90 is
        select ah.nro_cuenta,
               (nvl((ah.capital), 0)) saldo,
               nvl((nvl(pas_bcp.fu_obt_dev_cda(ah.nro_cuenta,
                                               ah.capital,
                                               ah.fec_apertura,
                                               P_FEC_ACTUAL),
                        0)),
                   0) mto_dev
          from ah_cta_certificados ah, ge_cta_clientes ct, ge_clientes cl
         where ah.fec_vencimiento - p_fec_actual between 31 and 90
           and ah.est_cer_batch not in ('V', 'P')
           and ah.est_batch NOT IN ('T', 'A', 'C', 'X')
           and ah.cod_moneda = V_MONEDA
           and ah.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and ct.cod_persona = cl.cod_persona
           and cl.cod_sec_contable = 'N'
              --agregado para quitar los retenidos--
           and nvl(ah.sal_ret_batch, 0) = 0;

      -- De 91 a 180 dias
      Cursor na180 is
        select ah.nro_cuenta,
               (nvl((ah.capital), 0)) saldo,
               nvl((nvl(pas_bcp.fu_obt_dev_cda(ah.nro_cuenta,
                                               ah.capital,
                                               ah.fec_apertura,
                                               P_FEC_ACTUAL),
                        0)),
                   0) mto_dev
          from ah_cta_certificados ah, ge_cta_clientes ct, ge_clientes cl
         where ah.fec_vencimiento - p_fec_actual between 91 and 180
           and ah.est_cer_batch not in ('V', 'P')
           and ah.est_batch NOT IN ('T', 'A', 'C', 'X')
           and ah.cod_moneda = V_MONEDA
           and ah.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and ct.cod_persona = cl.cod_persona
           and cl.cod_sec_contable = 'N'
              --agregado para quitar los retenidos--
           and nvl(ah.sal_ret_batch, 0) = 0;

      -- De 181 a 365 dias
      Cursor na365 is
        select ah.nro_cuenta,
               (nvl((ah.capital), 0)) saldo,
               nvl((nvl(pas_bcp.fu_obt_dev_cda(ah.nro_cuenta,
                                               ah.capital,
                                               ah.fec_apertura,
                                               P_FEC_ACTUAL),
                        0)),
                   0) mto_dev
          from ah_cta_certificados ah, ge_cta_clientes ct, ge_clientes cl
         where ah.fec_vencimiento - p_fec_actual between 181 and 365
           and ah.est_cer_batch not in ('V', 'P')
           and ah.est_batch NOT IN ('T', 'A', 'C', 'X')
           and ah.cod_moneda = V_MONEDA
           and ah.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and ct.cod_persona = cl.cod_persona
           and cl.cod_sec_contable = 'N'
              --agregado para quitar los retenidos--
           and nvl(ah.sal_ret_batch, 0) = 0;

      -- De 365 a 1095 dias(3 años)
      Cursor na1095 is
        select ah.nro_cuenta,
               (nvl((ah.capital), 0)) saldo,
               nvl((nvl(pas_bcp.fu_obt_dev_cda(ah.nro_cuenta,
                                               ah.capital,
                                               ah.fec_apertura,
                                               P_FEC_ACTUAL),
                        0)),
                   0) mto_dev
          from ah_cta_certificados ah, ge_cta_clientes ct, ge_clientes cl
         where ah.fec_vencimiento - p_fec_actual between 366 and 1095
           and ah.est_cer_batch not in ('V', 'P')
           and ah.est_batch NOT IN ('T', 'A', 'C', 'X')
           and ah.cod_moneda = V_MONEDA
           and ah.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and ct.cod_persona = cl.cod_persona
           and cl.cod_sec_contable = 'N'
              --agregado para quitar los retenidos--
           and nvl(ah.sal_ret_batch, 0) = 0;

      -- Mayor 1095 dias(3 años)
      Cursor nm1095 is
        select ah.nro_cuenta,
               (nvl((ah.capital), 0)) saldo,
               nvl((nvl(pas_bcp.fu_obt_dev_cda(ah.nro_cuenta,
                                               ah.capital,
                                               ah.fec_apertura,
                                               P_FEC_ACTUAL),
                        0)),
                   0) mto_dev
          from ah_cta_certificados ah, ge_cta_clientes ct, ge_clientes cl
         where ah.fec_vencimiento - p_fec_actual > 1095
           and ah.est_cer_batch not in ('V', 'P')
           and ah.est_batch NOT IN ('T', 'A', 'C', 'X')
           and ah.cod_moneda = V_MONEDA
           and ah.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and ct.cod_persona = cl.cod_persona
           and cl.cod_sec_contable = 'N'
              --agregado para quitar los retenidos--
           and nvl(ah.sal_ret_batch, 0) = 0;
    BEGIN
      V_MONEDA := PAS_BCP.FU_OBT_MON_FUERTE;
      -- Sector Financiero --
      For reg in fin loop
        LP_INS_REG_LIQUIDEZ(p_fec_actual,
                            'OBLIGACIONES SECTOR FINANCIERO',
                            V_MONEDA,
                            reg.nro_cuenta,
                            0,
                            reg.saldo,
                            1);
        V_SAL_ACTUAL := nvl(V_SAL_ACTUAL, 0) + reg.saldo;
      End loop;
      For reg in fin2 loop
        LP_INS_REG_LIQUIDEZ(p_fec_actual,
                            'OBLIGACIONES SECTOR FINANCIERO',
                            V_MONEDA,
                            reg.nro_cuenta,
                            reg.mto_dev,
                            reg.saldo,
                            1);
        V_SAL_ACTUAL := nvl(V_SAL_ACTUAL, 0) + nvl(reg.saldo, 0) +
                        nvl(reg.mto_dev, 0);
      End loop;
      For reg in men30 loop
        LP_INS_REG_LIQUIDEZ(p_fec_actual,
                            'OBLIGACIONES SECTOR FINANCIERO',
                            V_MONEDA,
                            reg.nro_cuenta,
                            reg.mto_dev,
                            reg.saldo,
                            30);
        V_MEN_30_DIAS := nvl(V_MEN_30_DIAS, 0) + nvl(reg.saldo, 0) +
                         nvl(reg.mto_dev, 0);
      End loop;
      For reg in a90 loop
        LP_INS_REG_LIQUIDEZ(p_fec_actual,
                            'OBLIGACIONES SECTOR FINANCIERO',
                            V_MONEDA,
                            reg.nro_cuenta,
                            reg.mto_dev,
                            reg.saldo,
                            90);
        V_MEN_90_DIAS := nvl(V_MEN_90_DIAS, 0) + nvl(reg.saldo, 0) +
                         nvl(reg.mto_dev, 0);
      End loop;
      For reg in a180 loop
        LP_INS_REG_LIQUIDEZ(p_fec_actual,
                            'OBLIGACIONES SECTOR FINANCIERO',
                            V_MONEDA,
                            reg.nro_cuenta,
                            reg.mto_dev,
                            reg.saldo,
                            180);
        V_MEN_180_DIAS := nvl(V_MEN_180_DIAS, 0) + nvl(reg.saldo, 0) +
                          nvl(reg.mto_dev, 0);
      End loop;
      For reg in a365 loop
        LP_INS_REG_LIQUIDEZ(p_fec_actual,
                            'OBLIGACIONES SECTOR FINANCIERO',
                            V_MONEDA,
                            reg.nro_cuenta,
                            reg.mto_dev,
                            reg.saldo,
                            365);
        V_MEN_1_ANO := nvl(V_MEN_1_ANO, 0) + nvl(reg.saldo, 0) +
                       nvl(reg.mto_dev, 0);
      End loop;
      For reg in a1095 loop
        LP_INS_REG_LIQUIDEZ(p_fec_actual,
                            'OBLIGACIONES SECTOR FINANCIERO',
                            V_MONEDA,
                            reg.nro_cuenta,
                            reg.mto_dev,
                            reg.saldo,
                            1095);
        V_MEN_3_ANOS := nvl(V_MEN_3_ANOS, 0) + nvl(reg.saldo, 0) +
                        nvl(reg.mto_dev, 0);
      End loop;
      For reg in m1095 loop
        LP_INS_REG_LIQUIDEZ(p_fec_actual,
                            'OBLIGACIONES SECTOR FINANCIERO',
                            V_MONEDA,
                            reg.nro_cuenta,
                            reg.mto_dev,
                            reg.saldo,
                            1096);
        V_MAY_3_ANOS := nvl(V_MEN_3_ANOS, 0) + nvl(reg.saldo, 0) +
                        nvl(reg.mto_dev, 0);
      End loop;
      insert into sb_liquidez
        (FECHA,
         COD_MONEDA,
         CUENTA,
         DESCRIPCION,
         PLZ_VISTA,
         MEN_30_DIAS,
         MEN_90_DIAS,
         MEN_180_DIAS,
         MEN_1_ANO,
         MEN_3_ANOS,
         MAY_3_ANOS)
      values
        (p_fec_actual,
         v_moneda,
         21000000000000,
         'OBLIGACIONES SECTOR FINANCIERO',
         v_sal_actual,
         v_men_30_dias,
         v_men_90_dias,
         v_men_180_dias,
         v_men_1_ano,
         v_men_3_anos,
         v_may_3_anos);

      -- Sector No Financiero --
      V_SAL_ACTUAL   := 0;
      V_MEN_30_DIAS  := 0;
      V_MEN_90_DIAS  := 0;
      V_MEN_180_DIAS := 0;
      V_MEN_1_ANO    := 0;
      V_MEN_3_ANOS   := 0;
      V_MAY_3_ANOS   := 0;
      For reg in nofin1 loop
        LP_INS_REG_LIQUIDEZ(p_fec_actual,
                            'OBLIGACIONES SECTOR NO FINANCIERO',
                            V_MONEDA,
                            reg.nro_cuenta,
                            0,
                            reg.saldo,
                            1);
        V_SAL_ACTUAL := nvl(V_SAL_ACTUAL, 0) + nvl(reg.saldo, 0);
      End loop;
      For reg in nofin2 loop
        LP_INS_REG_LIQUIDEZ(p_fec_actual,
                            'OBLIGACIONES SECTOR NO FINANCIERO',
                            V_MONEDA,
                            reg.nro_cuenta,
                            reg.mto_dev,
                            reg.saldo,
                            1);
        V_SAL_ACTUAL := nvl(V_SAL_ACTUAL, 0) + nvl(reg.saldo, 0) +
                        nvl(reg.mto_dev, 0);
      End loop;
      For reg in nmen30 loop
        LP_INS_REG_LIQUIDEZ(p_fec_actual,
                            'OBLIGACIONES SECTOR NO FINANCIERO',
                            V_MONEDA,
                            reg.nro_cuenta,
                            reg.mto_dev,
                            reg.saldo,
                            30);
        V_MEN_30_DIAS := nvl(V_MEN_30_DIAS, 0) + nvl(reg.saldo, 0) +
                         nvl(reg.mto_dev, 0);
      End loop;
      For reg in na90 loop
        LP_INS_REG_LIQUIDEZ(p_fec_actual,
                            'OBLIGACIONES SECTOR NO FINANCIERO',
                            V_MONEDA,
                            reg.nro_cuenta,
                            reg.mto_dev,
                            reg.saldo,
                            90);
        V_MEN_90_DIAS := nvl(V_MEN_90_DIAS, 0) + nvl(reg.saldo, 0) +
                         nvl(reg.mto_dev, 0);
      End loop;
      For reg in na180 loop
        LP_INS_REG_LIQUIDEZ(p_fec_actual,
                            'OBLIGACIONES SECTOR NO FINANCIERO',
                            V_MONEDA,
                            reg.nro_cuenta,
                            reg.mto_dev,
                            reg.saldo,
                            180);
        V_MEN_180_DIAS := nvl(V_MEN_180_DIAS, 0) + nvl(reg.saldo, 0) +
                          nvl(reg.mto_dev, 0);
      End loop;
      For reg in na365 loop
        LP_INS_REG_LIQUIDEZ(p_fec_actual,
                            'OBLIGACIONES SECTOR NO FINANCIERO',
                            V_MONEDA,
                            reg.nro_cuenta,
                            reg.mto_dev,
                            reg.saldo,
                            365);
        V_MEN_1_ANO := nvl(V_MEN_1_ANO, 0) + nvl(reg.saldo, 0) +
                       nvl(reg.mto_dev, 0);
      End loop;
      For reg in na1095 loop
        LP_INS_REG_LIQUIDEZ(p_fec_actual,
                            'OBLIGACIONES SECTOR NO FINANCIERO',
                            V_MONEDA,
                            reg.nro_cuenta,
                            reg.mto_dev,
                            reg.saldo,
                            1095);
        V_MEN_3_ANOS := nvl(V_MEN_3_ANOS, 0) + nvl(reg.saldo, 0) +
                        nvl(reg.mto_dev, 0);
      End loop;
      For reg in nm1095 loop
        LP_INS_REG_LIQUIDEZ(p_fec_actual,
                            'OBLIGACIONES SECTOR NO FINANCIERO',
                            V_MONEDA,
                            reg.nro_cuenta,
                            reg.mto_dev,
                            reg.saldo,
                            1096);
        V_MAY_3_ANOS := nvl(V_MAY_3_ANOS, 0) + nvl(reg.saldo, 0) +
                        nvl(reg.mto_dev, 0);
      End loop;
      insert into sb_liquidez
        (FECHA,
         COD_MONEDA,
         CUENTA,
         DESCRIPCION,
         PLZ_VISTA,
         MEN_30_DIAS,
         MEN_90_DIAS,
         MEN_180_DIAS,
         MEN_1_ANO,
         MEN_3_ANOS,
         MAY_3_ANOS)
      values
        (p_fec_actual,
         V_MONEDA,
         22000000000000,
         'OBLIGACIONES SECTOR NO FINANCIERO',
         v_sal_actual,
         v_men_30_dias,
         v_men_90_dias,
         v_men_180_dias,
         v_men_1_ano,
         v_men_3_anos,
         v_may_3_anos);
    END;
    /* Calcula la liquidez para moneda local */
    PROCEDURE LP_CAL_LIQ_MON_LOCAL(P_FEC_ACTUAL IN DATE) IS

      V_SAL_ACTUAL2  NUMBER(18, 2);
      V_SAL_ACTUAL1  NUMBER(18, 2);
      V_SAL_ACTUAL   NUMBER(18, 2);
      V_MEN_30_DIAS  NUMBER(18, 2);
      V_MEN_90_DIAS  NUMBER(18, 2);
      V_MEN_180_DIAS NUMBER(18, 2);
      V_MEN_1_ANO    NUMBER(18, 2);
      V_MEN_3_ANOS   NUMBER(18, 2);
      V_MAY_3_ANOS   NUMBER(18, 2);
      V_CUENTA       VARCHAR2(15);
      V_MONEDA       AH_CTA_CERTIFICADOS.COD_MONEDA%TYPE;
      -- MONEDA LOCAL --
      -- Sector financiero
      Cursor fin is
        select ah.nro_cuenta,
               round(nvl((decode(ah.est_cer_batch,
                                 'V',
                                 ah.sal_tot_batch,
                                 'P',
                                 ah.sal_tot_batch,
                                 ah.sal_tot_batch - ah.capital)),
                         0),
                     0) saldo
          from ah_cta_certificados ah, ge_cta_clientes ct, ge_clientes cl
         where ah.est_batch NOT IN ('T', 'A', 'C', 'X')
           and (est_cer_batch IN ('V', 'P') or sal_tot_batch > capital)
           and ah.cod_moneda = V_MONEDA
           and ah.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and ct.cod_persona = cl.cod_persona
           and cl.cod_sec_contable IN ('F', 'P', 'I') --- Financiero y Publico
              --agregado para quitar los retenidos--
           and nvl(ah.sal_ret_batch, 0) = 0;

      Cursor fin1 is
        select ah.nro_cuenta,
               round(nvl((ah.sal_tot_batch), 0), 0) saldo,
               nvl((nvl(decode(ah.fec_ult_capitalizacion,
                               p_fec_actual,
                               0,
                               pas_bcp.fu_obt_dev_av(ah.nro_cuenta,
                                                     P_FEC_ACTUAL)),
                        0)),
                   0) mto_dev
          from ah_cta_vistas ah, ge_cta_clientes ct, ge_clientes cl
         where ah.cod_moneda = V_MONEDA
           and ah.est_batch not in ('A', 'C') --Abierta y cancelada;
           and ah.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and ct.cod_persona = cl.cod_persona
           and cl.cod_sec_contable IN ('F', 'P', 'I'); --- Financiero y Publico

      -- Menores a 30 días
      Cursor men30 is
        select ah.nro_cuenta,
               round(nvl((ah.capital), 0), 0) saldo,
               nvl((nvl(pas_bcp.fu_obt_dev_cda(ah.nro_cuenta,
                                               ah.capital,
                                               ah.fec_apertura,
                                               P_FEC_ACTUAL),
                        0)),
                   0) mto_dev
          from ah_cta_certificados ah, ge_cta_clientes ct, ge_clientes cl
         where ah.fec_vencimiento - p_fec_actual <= 30
           and ah.est_cer_batch not in ('V', 'P')
           and ah.est_batch NOT IN ('T', 'A', 'C', 'X')
           and ah.cod_moneda = V_MONEDA
           and ah.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and ct.cod_persona = cl.cod_persona
           and cl.cod_sec_contable IN ('F', 'P', 'I') --- Financiero y Publico
              --agregado para quitar los retenidos--
           and nvl(ah.sal_ret_batch, 0) = 0;

      -- De 31 a 90 días
      Cursor a90 is
        select ah.nro_cuenta,
               round(nvl((ah.capital), 0), 0) saldo,
               nvl((nvl(pas_bcp.fu_obt_dev_cda(ah.nro_cuenta,
                                               ah.capital,
                                               ah.fec_apertura,
                                               P_FEC_ACTUAL),
                        0)),
                   0) mto_dev
          from ah_cta_certificados ah, ge_cta_clientes ct, ge_clientes cl
         where ah.fec_vencimiento - p_fec_actual between 31 and 90
           and ah.est_cer_batch not in ('V', 'P')
           and ah.est_batch NOT IN ('T', 'A', 'C', 'X')
           and ah.cod_moneda = V_MONEDA
           and ah.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and ct.cod_persona = cl.cod_persona
           and cl.cod_sec_contable IN ('F', 'P', 'I') --- Financiero y Publico
              --agregado para quitar los retenidos--
           and nvl(ah.sal_ret_batch, 0) = 0;

      -- De 91 a 180 dias
      Cursor a180 is
        select ah.nro_cuenta,
               round(nvl((ah.capital), 0), 0) saldo,
               nvl((nvl(pas_bcp.fu_obt_dev_cda(ah.nro_cuenta,
                                               ah.capital,
                                               ah.fec_apertura,
                                               P_FEC_ACTUAL),
                        0)),
                   0) mto_dev
          from ah_cta_certificados ah, ge_cta_clientes ct, ge_clientes cl
         where ah.fec_vencimiento - p_fec_actual between 91 and 180
           and ah.est_cer_batch not in ('V', 'P')
           and ah.est_batch NOT IN ('T', 'A', 'C', 'X')
           and ah.cod_moneda = V_MONEDA
           and ah.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and ct.cod_persona = cl.cod_persona
           and cl.cod_sec_contable IN ('F', 'P', 'I') --- Financiero y Publico
              --agregado para quitar los retenidos--
           and nvl(ah.sal_ret_batch, 0) = 0;

      -- De 181 a 365 dias
      Cursor a365 is
        select ah.nro_cuenta,
               round(nvl((ah.capital), 0), 0) saldo,
               nvl((nvl(pas_bcp.fu_obt_dev_cda(ah.nro_cuenta,
                                               ah.capital,
                                               ah.fec_apertura,
                                               P_FEC_ACTUAL),
                        0)),
                   0) mto_dev
          from ah_cta_certificados ah, ge_cta_clientes ct, ge_clientes cl
         where ah.fec_vencimiento - p_fec_actual between 181 and 365
           and ah.est_cer_batch not in ('V', 'P')
           and ah.est_batch NOT IN ('T', 'A', 'C', 'X')
           and ah.cod_moneda = V_MONEDA
           and ah.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and ct.cod_persona = cl.cod_persona
           and cl.cod_sec_contable IN ('F', 'P', 'I') --- Financiero y Publico
              --agregado para quitar los retenidos--
           and nvl(ah.sal_ret_batch, 0) = 0;

      -- De 365 a 1095 dias(3 años)
      Cursor a1095 is
        select ah.nro_cuenta,
               round(nvl((ah.capital), 0), 0) saldo,
               nvl((nvl(pas_bcp.fu_obt_dev_cda(ah.nro_cuenta,
                                               ah.capital,
                                               ah.fec_apertura,
                                               P_FEC_ACTUAL),
                        0)),
                   0) mto_dev
          from ah_cta_certificados ah, ge_cta_clientes ct, ge_clientes cl
         where ah.fec_vencimiento - p_fec_actual between 366 and 1095
           and ah.est_cer_batch not in ('V', 'P')
           and ah.est_batch NOT IN ('T', 'A', 'C', 'X')
           and ah.cod_moneda = V_MONEDA
           and ah.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and ct.cod_persona = cl.cod_persona
           and cl.cod_sec_contable IN ('F', 'P', 'I') --- Financiero y Publico
              --agregado para quitar los retenidos--
           and nvl(ah.sal_ret_batch, 0) = 0;

      -- Mayor 1095 dias(3 años)
      Cursor m1095 is
        select ah.nro_cuenta,
               round(nvl((ah.capital), 0), 0) saldo,
               nvl((nvl(pas_bcp.fu_obt_dev_cda(ah.nro_cuenta,
                                               ah.capital,
                                               ah.fec_apertura,
                                               P_FEC_ACTUAL),
                        0)),
                   0) mto_dev
          from ah_cta_certificados ah, ge_cta_clientes ct, ge_clientes cl
         where ah.fec_vencimiento - p_fec_actual > 1095
           and ah.est_cer_batch not in ('V', 'P')
           and ah.est_batch NOT IN ('T', 'A', 'C', 'X')
           and ah.cod_moneda = V_MONEDA
           and ah.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and ct.cod_persona = cl.cod_persona
           and cl.cod_sec_contable IN ('F', 'P', 'I') --- Financiero y Publico
              --agregado para quitar los retenidos--
           and nvl(ah.sal_ret_batch, 0) = 0;

      --sector no financiero
      Cursor nofin1 is
        select ah.nro_cuenta,
               round(nvl((decode(ah.est_cer_batch,
                                 'V',
                                 ah.sal_tot_batch,
                                 'P',
                                 ah.sal_tot_batch,
                                 ah.sal_tot_batch - ah.capital)),
                         0),
                     0) saldo
          from ah_cta_certificados ah, ge_cta_clientes ct, ge_clientes cl
         where ah.est_batch NOT IN ('T', 'A', 'C', 'X')
           and (est_cer_batch in ('V', 'P') or sal_tot_batch > capital)
           and ah.cod_moneda = V_MONEDA
           and ah.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and ct.cod_persona = cl.cod_persona
           and cl.cod_sec_contable = 'N'
              --agregado para quitar los retenidos--
           and nvl(ah.sal_ret_batch, 0) = 0;

      Cursor nofin2 is
        select ah.nro_cuenta,
               round(nvl((ah.sal_tot_batch), 0), 0) saldo,
               nvl((nvl(decode(ah.fec_ult_capitalizacion,
                               p_fec_actual,
                               0,
                               pas_bcp.fu_obt_dev_av(ah.nro_cuenta,
                                                     P_FEC_ACTUAL)),
                        0)),
                   0) mto_dev
          from ah_cta_vistas ah, ge_cta_clientes ct, ge_clientes cl
         where ah.cod_moneda = V_MONEDA
           and ah.est_batch not in ('A', 'C') --Abierta y cancelada;
           and ah.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and ct.cod_persona = cl.cod_persona
           and cl.cod_sec_contable = 'N';

      -- Menores a 30 días
      Cursor nmen30 is
        select ah.nro_cuenta,
               round(nvl((ah.capital), 0), 0) saldo,
               nvl((nvl(pas_bcp.fu_obt_dev_cda(ah.nro_cuenta,
                                               ah.capital,
                                               ah.fec_apertura,
                                               P_FEC_ACTUAL),
                        0)),
                   0) mto_dev
          from ah_cta_certificados ah, ge_cta_clientes ct, ge_clientes cl
         where ah.fec_vencimiento - p_fec_actual <= 30
           and ah.est_cer_batch not in ('V', 'P')
           and ah.est_batch NOT IN ('T', 'A', 'C', 'X')
           and ah.cod_moneda = V_MONEDA
           and ah.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and ct.cod_persona = cl.cod_persona
           and cl.cod_sec_contable = 'N'
              --agregado para quitar los retenidos--
           and nvl(ah.sal_ret_batch, 0) = 0;

      -- De 31 a 90 días
      Cursor na90 is
        select ah.nro_cuenta,
               round(nvl((ah.capital), 0), 0) saldo,
               nvl((nvl(pas_bcp.fu_obt_dev_cda(ah.nro_cuenta,
                                               ah.capital,
                                               ah.fec_apertura,
                                               P_FEC_ACTUAL),
                        0)),
                   0) mto_dev
          from ah_cta_certificados ah, ge_cta_clientes ct, ge_clientes cl
         where ah.fec_vencimiento - p_fec_actual between 31 and 90
           and ah.est_cer_batch not in ('V', 'P')
           and ah.est_batch NOT IN ('T', 'A', 'C', 'X')
           and ah.cod_moneda = V_MONEDA
           and ah.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and ct.cod_persona = cl.cod_persona
           and cl.cod_sec_contable = 'N'
              --agregado para quitar los retenidos--
           and nvl(ah.sal_ret_batch, 0) = 0;

      -- De 91 a 180 dias
      Cursor na180 is
        select ah.nro_cuenta,
               round(nvl((ah.capital), 0), 0) saldo,
               nvl((nvl(pas_bcp.fu_obt_dev_cda(ah.nro_cuenta,
                                               ah.capital,
                                               ah.fec_apertura,
                                               P_FEC_ACTUAL),
                        0)),
                   0) mto_dev
          from ah_cta_certificados ah, ge_cta_clientes ct, ge_clientes cl
         where ah.fec_vencimiento - p_fec_actual between 91 and 180
           and ah.est_cer_batch not in ('V', 'P')
           and ah.est_batch NOT IN ('T', 'A', 'C', 'X')
           and ah.cod_moneda = V_MONEDA
           and ah.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and ct.cod_persona = cl.cod_persona
           and cl.cod_sec_contable = 'N'
              --agregado para quitar los retenidos--
           and nvl(ah.sal_ret_batch, 0) = 0;

      -- De 181 a 365 dias
      Cursor na365 is
        select ah.nro_cuenta,
               round(nvl((ah.capital), 0), 0) saldo,
               nvl((nvl(pas_bcp.fu_obt_dev_cda(ah.nro_cuenta,
                                               ah.capital,
                                               ah.fec_apertura,
                                               P_FEC_ACTUAL),
                        0)),
                   0) mto_dev
          from ah_cta_certificados ah, ge_cta_clientes ct, ge_clientes cl
         where ah.fec_vencimiento - p_fec_actual between 181 and 365
           and ah.est_cer_batch not in ('V', 'P')
           and ah.est_batch NOT IN ('T', 'A', 'C', 'X')
           and ah.cod_moneda = V_MONEDA
           and ah.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and ct.cod_persona = cl.cod_persona
           and cl.cod_sec_contable = 'N'
              --agregado para quitar los retenidos--
           and nvl(ah.sal_ret_batch, 0) = 0;

      -- De 365 a 1095 dias(3 años)
      Cursor na1095 is
        select ah.nro_cuenta,
               round(nvl((ah.capital), 0), 0) saldo,
               nvl((nvl(pas_bcp.fu_obt_dev_cda(ah.nro_cuenta,
                                               ah.capital,
                                               ah.fec_apertura,
                                               P_FEC_ACTUAL),
                        0)),
                   0) mto_dev
          from ah_cta_certificados ah, ge_cta_clientes ct, ge_clientes cl
         where ah.fec_vencimiento - p_fec_actual between 366 and 1095
           and ah.est_cer_batch not in ('V', 'P')
           and ah.est_batch NOT IN ('T', 'A', 'C', 'X')
           and ah.cod_moneda = V_MONEDA
           and ah.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and ct.cod_persona = cl.cod_persona
           and cl.cod_sec_contable = 'N'
              --agregado para quitar los retenidos--
           and nvl(ah.sal_ret_batch, 0) = 0;

      -- Mayor 1095 dias(3 años)
      Cursor nm1095 is
        select ah.nro_cuenta,
               round(nvl((ah.capital), 0), 0) saldo,
               nvl((nvl(pas_bcp.fu_obt_dev_cda(ah.nro_cuenta,
                                               ah.capital,
                                               ah.fec_apertura,
                                               P_FEC_ACTUAL),
                        0)),
                   0) mto_dev
          from ah_cta_certificados ah, ge_cta_clientes ct, ge_clientes cl
         where ah.fec_vencimiento - p_fec_actual > 1095
           and ah.est_cer_batch not in ('V', 'P')
           and ah.est_batch NOT IN ('T', 'A', 'C', 'X')
           and ah.cod_moneda = V_MONEDA
           and ah.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and ct.cod_persona = cl.cod_persona
           and cl.cod_sec_contable = 'N'
              --agregado para quitar los retenidos--
           and nvl(ah.sal_ret_batch, 0) = 0;
    BEGIN
      V_MONEDA := pag_gen.fu_obt_mon_local;
      -- Sector Financiero --
      For reg in fin loop
        LP_INS_REG_LIQUIDEZ(p_fec_actual,
                            'OBLIGACIONES SECTOR FINANCIERO',
                            V_MONEDA,
                            reg.nro_cuenta,
                            0,
                            reg.saldo,
                            1);
        V_SAL_ACTUAL := nvl(V_SAL_ACTUAL, 0) + nvl(reg.saldo, 0);
      End loop;
      For reg in fin1 loop
        LP_INS_REG_LIQUIDEZ(p_fec_actual,
                            'OBLIGACIONES SECTOR FINANCIERO',
                            V_MONEDA,
                            reg.nro_cuenta,
                            reg.mto_dev,
                            reg.saldo,
                            1);
        V_SAL_ACTUAL := nvl(V_SAL_ACTUAL, 0) + nvl(reg.saldo, 0) +
                        nvl(reg.mto_dev, 0);
      End loop;
      For reg in men30 loop
        LP_INS_REG_LIQUIDEZ(p_fec_actual,
                            'OBLIGACIONES SECTOR FINANCIERO',
                            V_MONEDA,
                            reg.nro_cuenta,
                            reg.mto_dev,
                            reg.saldo,
                            30);
        V_MEN_30_DIAS := nvl(V_MEN_30_DIAS, 0) + nvl(reg.saldo, 0) +
                         nvl(reg.mto_dev, 0);
      End loop;
      For reg in a90 loop
        LP_INS_REG_LIQUIDEZ(p_fec_actual,
                            'OBLIGACIONES SECTOR FINANCIERO',
                            V_MONEDA,
                            reg.nro_cuenta,
                            reg.mto_dev,
                            reg.saldo,
                            90);
        V_MEN_90_DIAS := nvl(V_MEN_90_DIAS, 0) + nvl(reg.saldo, 0) +
                         nvl(reg.mto_dev, 0);
      End loop;
      For reg in a180 loop
        LP_INS_REG_LIQUIDEZ(p_fec_actual,
                            'OBLIGACIONES SECTOR FINANCIERO',
                            V_MONEDA,
                            reg.nro_cuenta,
                            reg.mto_dev,
                            reg.saldo,
                            180);
        V_MEN_180_DIAS := nvl(V_MEN_180_DIAS, 0) + nvl(reg.saldo, 0) +
                          nvl(reg.mto_dev, 0);
      End loop;
      For reg in a365 loop
        LP_INS_REG_LIQUIDEZ(p_fec_actual,
                            'OBLIGACIONES SECTOR FINANCIERO',
                            V_MONEDA,
                            reg.nro_cuenta,
                            reg.mto_dev,
                            reg.saldo,
                            365);
        V_MEN_1_ANO := nvl(V_MEN_1_ANO, 0) + nvl(reg.saldo, 0) +
                       nvl(reg.mto_dev, 0);
      End loop;
      For reg in a1095 loop
        LP_INS_REG_LIQUIDEZ(p_fec_actual,
                            'OBLIGACIONES SECTOR FINANCIERO',
                            V_MONEDA,
                            reg.nro_cuenta,
                            reg.mto_dev,
                            reg.saldo,
                            1095);
        V_MEN_3_ANOS := nvl(V_MEN_3_ANOS, 0) + nvl(reg.saldo, 0) +
                        nvl(reg.mto_dev, 0);
      End loop;
      For reg in m1095 loop
        LP_INS_REG_LIQUIDEZ(p_fec_actual,
                            'OBLIGACIONES SECTOR FINANCIERO',
                            V_MONEDA,
                            reg.nro_cuenta,
                            reg.mto_dev,
                            reg.saldo,
                            1096);
        V_MAY_3_ANOS := nvl(V_MAY_3_ANOS, 0) + nvl(reg.saldo, 0) +
                        nvl(reg.mto_dev, 0);
      End loop;
      insert into sb_liquidez
        (FECHA,
         COD_MONEDA,
         CUENTA,
         DESCRIPCION,
         PLZ_VISTA,
         MEN_30_DIAS,
         MEN_90_DIAS,
         MEN_180_DIAS,
         MEN_1_ANO,
         MEN_3_ANOS,
         MAY_3_ANOS)
      values
        (p_fec_actual,
         V_MONEDA,
         21000000000000,
         'OBLIGACIONES SECTOR FINANCIERO',
         v_sal_actual,
         v_men_30_dias,
         v_men_90_dias,
         v_men_180_dias,
         v_men_1_ano,
         v_men_3_anos,
         v_may_3_anos);

      -- Sector No Financiero --
      V_SAL_ACTUAL   := 0;
      V_MEN_30_DIAS  := 0;
      V_MEN_90_DIAS  := 0;
      V_MEN_180_DIAS := 0;
      V_MEN_1_ANO    := 0;
      V_MEN_3_ANOS   := 0;
      V_MAY_3_ANOS   := 0;
      For reg in nofin1 loop
        LP_INS_REG_LIQUIDEZ(p_fec_actual,
                            'OBLIGACIONES SECTOR NO FINANCIERO',
                            V_MONEDA,
                            reg.nro_cuenta,
                            0,
                            reg.saldo,
                            1);
        V_SAL_ACTUAL := nvl(V_SAL_ACTUAL, 0) + nvl(reg.saldo, 0);
      End loop;
      For reg in nofin2 loop
        LP_INS_REG_LIQUIDEZ(p_fec_actual,
                            'OBLIGACIONES SECTOR NO FINANCIERO',
                            V_MONEDA,
                            reg.nro_cuenta,
                            reg.mto_dev,
                            reg.saldo,
                            1);
        V_SAL_ACTUAL := nvl(V_SAL_ACTUAL, 0) + nvl(reg.saldo, 0) +
                        nvl(reg.mto_dev, 0);
      End loop;
      For reg in nmen30 loop
        LP_INS_REG_LIQUIDEZ(p_fec_actual,
                            'OBLIGACIONES SECTOR NO FINANCIERO',
                            V_MONEDA,
                            reg.nro_cuenta,
                            reg.mto_dev,
                            reg.saldo,
                            30);
        V_MEN_30_DIAS := nvl(V_MEN_30_DIAS, 0) + nvl(reg.saldo, 0) +
                         nvl(reg.mto_dev, 0);
      End loop;
      For reg in na90 loop
        LP_INS_REG_LIQUIDEZ(p_fec_actual,
                            'OBLIGACIONES SECTOR NO FINANCIERO',
                            V_MONEDA,
                            reg.nro_cuenta,
                            reg.mto_dev,
                            reg.saldo,
                            90);
        V_MEN_90_DIAS := nvl(V_MEN_90_DIAS, 0) + nvl(reg.saldo, 0) +
                         nvl(reg.mto_dev, 0);
      End loop;
      For reg in na180 loop
        LP_INS_REG_LIQUIDEZ(p_fec_actual,
                            'OBLIGACIONES SECTOR NO FINANCIERO',
                            V_MONEDA,
                            reg.nro_cuenta,
                            reg.mto_dev,
                            reg.saldo,
                            180);
        V_MEN_180_DIAS := nvl(V_MEN_180_DIAS, 0) + nvl(reg.saldo, 0) +
                          nvl(reg.mto_dev, 0);
      End loop;
      For reg in na365 loop
        LP_INS_REG_LIQUIDEZ(p_fec_actual,
                            'OBLIGACIONES SECTOR NO FINANCIERO',
                            V_MONEDA,
                            reg.nro_cuenta,
                            reg.mto_dev,
                            reg.saldo,
                            365);
        V_MEN_1_ANO := nvl(V_MEN_1_ANO, 0) + nvl(reg.saldo, 0) +
                       nvl(reg.mto_dev, 0);
      End loop;
      For reg in na1095 loop
        LP_INS_REG_LIQUIDEZ(p_fec_actual,
                            'OBLIGACIONES SECTOR NO FINANCIERO',
                            V_MONEDA,
                            reg.nro_cuenta,
                            reg.mto_dev,
                            reg.saldo,
                            1095);
        V_MEN_3_ANOS := nvl(V_MEN_3_ANOS, 0) + nvl(reg.saldo, 0) +
                        nvl(reg.mto_dev, 0);
      End loop;
      For reg in nm1095 loop
        LP_INS_REG_LIQUIDEZ(p_fec_actual,
                            'OBLIGACIONES SECTOR NO FINANCIERO',
                            V_MONEDA,
                            reg.nro_cuenta,
                            reg.mto_dev,
                            reg.saldo,
                            1096);
        V_MAY_3_ANOS := nvl(V_MAY_3_ANOS, 0) + nvl(reg.saldo, 0) +
                        nvl(reg.mto_dev, 0);
      End loop;
      insert into sb_liquidez
        (FECHA,
         COD_MONEDA,
         CUENTA,
         DESCRIPCION,
         PLZ_VISTA,
         MEN_30_DIAS,
         MEN_90_DIAS,
         MEN_180_DIAS,
         MEN_1_ANO,
         MEN_3_ANOS,
         MAY_3_ANOS)
      values
        (p_fec_actual,
         V_MONEDA,
         22000000000000,
         'OBLIGACIONES SECTOR NO FINANCIERO',
         v_sal_actual,
         v_men_30_dias,
         v_men_90_dias,
         v_men_180_dias,
         v_men_1_ano,
         v_men_3_anos,
         v_may_3_anos);
    END;
    /* Inserta registro de liquidez */
    PROCEDURE LP_INS_REG_LIQUIDEZ(P_FEC_ACTUAL  IN DATE,
                                  P_DESCRIPCION IN VARCHAR2,
                                  P_MONEDA      IN VARCHAR2,
                                  P_NROCTA      IN VARCHAR2,
                                  P_MTODEV      IN NUMBER,
                                  P_MTOCAP      IN NUMBER,
                                  P_PLAZO       IN NUMBER,
                                  P_MTOPREV     IN NUMBER DEFAULT 0) IS
    Begin
      --If p_nrocta is not null then
      insert into sb_liquidez_det
        (FECHA,
         DESCRIPCION,
         COD_MONEDA,
         NRO_CUENTA,
         MTO_DEVENGADO,
         MTO_CAPITAL,
         PLAZO,
         MTO_PREVISION)
      values
        (p_fec_actual,
         p_descripcion,
         p_moneda,
         p_nrocta,
         p_mtodev,
         p_mtocap,
         p_plazo,
         P_MTOPREV);
      --End if;
    End;
    /* Calcula la liquidez préstamos para moneda extranjera */
    PROCEDURE LP_CAL_LIQ_MONEXT_PR(P_FEC_ACTUAL IN DATE) IS

      V_SAL_ACTUAL2  NUMBER(18, 2);
      V_SAL_ACTUAL1  NUMBER(18, 2);
      V_SAL_ACTUAL   NUMBER(18, 2);
      V_MEN_30_DIAS  NUMBER(18, 2);
      V_MEN_90_DIAS  NUMBER(18, 2);
      V_MEN_180_DIAS NUMBER(18, 2);
      V_MEN_1_ANO    NUMBER(18, 2);
      V_MEN_3_ANOS   NUMBER(18, 2);
      V_MAY_3_ANOS   NUMBER(18, 2);
      V_CUENTA       VARCHAR2(15);
      V_MONEDA       AH_CTA_CERTIFICADOS.COD_MONEDA%TYPE;
      -- MONEDA EXTRANJERA --
      --sector financiero
      --plazos vistas vencidos menor a hoy
      Cursor fin is
        select pr.nro_cuenta, nvl(pr.sal_cap_batch, 0) saldo
          from pr_cta_prestamos pr, ge_cta_clientes ct, ge_clientes cl
         where pr.est_batch in ('C', 'A') --C=Vigente,A=Vigente c/atraso
           and pr.fec_vencimiento < p_fec_actual --ya vencidos
           and pr.cod_moneda = V_MONEDA
           and pr.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and ct.cod_persona = cl.cod_persona
           and cl.cod_sec_contable IN ('F', 'P', 'I'); --- Financiero y Publico

      -- Menores a 30 días
      Cursor men30 is
        select pr.nro_cuenta,
               nvl(pr.sal_cap_batch, 0) saldo,
               nvl(dev_acumulado, 0) mto_dev
          from pr_cta_prestamos pr, ge_cta_clientes ct, ge_clientes cl
         where pr.fec_vencimiento - p_fec_actual between 1 and 30 --q venzan a partir de mañana
           and pr.est_batch in ('C', 'A') --C=Vigente,A=Vigente c/atraso
           and pr.cod_moneda = V_MONEDA
           and pr.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and ct.cod_persona = cl.cod_persona
           and cl.cod_sec_contable IN ('F', 'P', 'I'); --- Financiero y Publico

      -- De 31 a 90 días
      Cursor a90 is
        select pr.nro_cuenta,
               nvl(pr.sal_cap_batch, 0) saldo,
               nvl(dev_acumulado, 0) mto_dev
          from pr_cta_prestamos pr, ge_cta_clientes ct, ge_clientes cl
         where pr.fec_vencimiento - p_fec_actual between 31 and 90
           and pr.est_batch in ('C', 'A') --C=Vigente,A=Vigente c/atraso
           and pr.cod_moneda = V_MONEDA
           and pr.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and ct.cod_persona = cl.cod_persona
           and cl.cod_sec_contable IN ('F', 'P', 'I'); --- Financiero y Publico

      -- De 91 a 180 dias
      Cursor a180 is
        select pr.nro_cuenta,
               nvl(pr.sal_cap_batch, 0) saldo,
               nvl(dev_acumulado, 0) mto_dev
          from pr_cta_prestamos pr, ge_cta_clientes ct, ge_clientes cl
         where pr.fec_vencimiento - p_fec_actual between 91 and 180
           and pr.est_batch in ('C', 'A') --C=Vigente,A=Vigente c/atraso
           and pr.cod_moneda = V_MONEDA
           and pr.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and ct.cod_persona = cl.cod_persona
           and cl.cod_sec_contable IN ('F', 'P', 'I'); --- Financiero y Publico

      -- De 181 a 365 dias
      Cursor a365 is
        select pr.nro_cuenta,
               nvl(pr.sal_cap_batch, 0) saldo,
               nvl(dev_acumulado, 0) mto_dev
          from pr_cta_prestamos pr, ge_cta_clientes ct, ge_clientes cl
         where pr.fec_vencimiento - p_fec_actual between 181 and 365
           and pr.est_batch in ('C', 'A') --C=Vigente,A=Vigente c/atraso
           and pr.cod_moneda = V_MONEDA
           and pr.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and ct.cod_persona = cl.cod_persona
           and cl.cod_sec_contable IN ('F', 'P', 'I'); --- Financiero y Publico

      -- De 365 a 1095 dias(3 años)
      Cursor a1095 is
        select pr.nro_cuenta,
               nvl(pr.sal_cap_batch, 0) saldo,
               nvl(dev_acumulado, 0) mto_dev
          from pr_cta_prestamos pr, ge_cta_clientes ct, ge_clientes cl
         where pr.fec_vencimiento - p_fec_actual between 366 and 1095
           and pr.est_batch in ('C', 'A') --C=Vigente,A=Vigente c/atraso
           and pr.cod_moneda = V_MONEDA
           and pr.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and ct.cod_persona = cl.cod_persona
           and cl.cod_sec_contable IN ('F', 'P', 'I'); --- Financiero y Publico

      -- Mayor 1095 dias(3 años)
      Cursor m1095 is
        select pr.nro_cuenta,
               nvl(pr.sal_cap_batch, 0) saldo,
               nvl(dev_acumulado, 0) mto_dev
          from pr_cta_prestamos pr, ge_cta_clientes ct, ge_clientes cl
         where pr.fec_vencimiento - p_fec_actual > 1095
           and pr.est_batch in ('C', 'A') --C=Vigente,A=Vigente c/atraso
           and pr.cod_moneda = V_MONEDA
           and pr.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and ct.cod_persona = cl.cod_persona
           and cl.cod_sec_contable IN ('F', 'P', 'I'); --- Financiero y Publico

      --sector no financiero
      Cursor nfin is
        select pr.nro_cuenta, nvl(pr.sal_cap_batch, 0) saldo
          from pr_cta_prestamos pr, ge_cta_clientes ct, ge_clientes cl
         where pr.est_batch in ('C', 'A') --C=Vigente,A=Vigente c/atraso
           and pr.fec_vencimiento < p_fec_actual --ya vencidos
           and pr.cod_moneda = V_MONEDA
           and pr.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and ct.cod_persona = cl.cod_persona
           and cl.cod_sec_contable = 'N';

      -- Menores a 30 días
      Cursor nmen30 is
        select pr.nro_cuenta,
               nvl(pr.sal_cap_batch, 0) saldo,
               nvl(dev_acumulado, 0) mto_dev
          from pr_cta_prestamos pr, ge_cta_clientes ct, ge_clientes cl
         where pr.fec_vencimiento - p_fec_actual between 1 and 30 --q venzan a partir de mañana
           and pr.est_batch in ('C', 'A') --C=Vigente,A=Vigente c/atraso
           and pr.cod_moneda = V_MONEDA
           and pr.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and ct.cod_persona = cl.cod_persona
           and cl.cod_sec_contable = 'N';

      -- De 31 a 90 días
      Cursor na90 is
        select pr.nro_cuenta,
               nvl(pr.sal_cap_batch, 0) saldo,
               nvl(dev_acumulado, 0) mto_dev
          from pr_cta_prestamos pr, ge_cta_clientes ct, ge_clientes cl
         where pr.fec_vencimiento - p_fec_actual between 31 and 90
           and pr.est_batch in ('C', 'A') --C=Vigente,A=Vigente c/atraso
           and pr.cod_moneda = V_MONEDA
           and pr.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and ct.cod_persona = cl.cod_persona
           and cl.cod_sec_contable = 'N';

      -- De 91 a 180 dias
      Cursor na180 is
        select pr.nro_cuenta,
               nvl(pr.sal_cap_batch, 0) saldo,
               nvl(dev_acumulado, 0) mto_dev
          from pr_cta_prestamos pr, ge_cta_clientes ct, ge_clientes cl
         where pr.fec_vencimiento - p_fec_actual between 91 and 180
           and pr.est_batch in ('C', 'A') --C=Vigente,A=Vigente c/atraso
           and pr.cod_moneda = V_MONEDA
           and pr.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and ct.cod_persona = cl.cod_persona
           and cl.cod_sec_contable = 'N';

      -- De 181 a 365 dias
      Cursor na365 is
        select pr.nro_cuenta,
               nvl(pr.sal_cap_batch, 0) saldo,
               nvl(dev_acumulado, 0) mto_dev
          from pr_cta_prestamos pr, ge_cta_clientes ct, ge_clientes cl
         where pr.fec_vencimiento - p_fec_actual between 181 and 365
           and pr.est_batch in ('C', 'A') --C=Vigente,A=Vigente c/atraso
           and pr.cod_moneda = V_MONEDA
           and pr.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and ct.cod_persona = cl.cod_persona
           and cl.cod_sec_contable = 'N';

      -- De 365 a 1095 dias(3 años)
      Cursor na1095 is
        select pr.nro_cuenta,
               nvl(pr.sal_cap_batch, 0) saldo,
               nvl(dev_acumulado, 0) mto_dev
          from pr_cta_prestamos pr, ge_cta_clientes ct, ge_clientes cl
         where pr.fec_vencimiento - p_fec_actual between 366 and 1095
           and pr.est_batch in ('C', 'A') --C=Vigente,A=Vigente c/atraso
           and pr.cod_moneda = V_MONEDA
           and pr.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and ct.cod_persona = cl.cod_persona
           and cl.cod_sec_contable = 'N';

      -- Mayor 1095 dias(3 años)
      Cursor nm1095 is
        select pr.nro_cuenta,
               nvl(pr.sal_cap_batch, 0) saldo,
               nvl(dev_acumulado, 0) mto_dev
          from pr_cta_prestamos pr, ge_cta_clientes ct, ge_clientes cl
         where pr.fec_vencimiento - p_fec_actual > 1095
           and pr.est_batch in ('C', 'A') --C=Vigente,A=Vigente c/atraso
           and pr.cod_moneda = V_MONEDA
           and pr.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and ct.cod_persona = cl.cod_persona
           and cl.cod_sec_contable = 'N';
    BEGIN
      V_MONEDA := PAS_BCP.FU_OBT_MON_FUERTE;
      -- Sector Financiero --
      V_SAL_ACTUAL   := 0;
      V_MEN_30_DIAS  := 0;
      V_MEN_90_DIAS  := 0;
      V_MEN_180_DIAS := 0;
      V_MEN_1_ANO    := 0;
      V_MEN_3_ANOS   := 0;
      V_MAY_3_ANOS   := 0;

      For reg in fin loop
        LP_INS_REG_LIQUIDEZ(p_fec_actual,
                            'CREDITOS VIGENTES SECTOR FINANCIERO',
                            V_MONEDA,
                            reg.nro_cuenta,
                            0,
                            reg.saldo,
                            1);
        V_SAL_ACTUAL := nvl(V_SAL_ACTUAL, 0) + nvl(reg.saldo, 0);
      End loop;
      For reg in men30 loop
        LP_INS_REG_LIQUIDEZ(p_fec_actual,
                            'CREDITOS VIGENTES SECTOR FINANCIERO',
                            V_MONEDA,
                            reg.nro_cuenta,
                            reg.mto_dev,
                            reg.saldo,
                            30);
        V_MEN_30_DIAS := nvl(V_MEN_30_DIAS, 0) + nvl(reg.saldo, 0) +
                         nvl(reg.mto_dev, 0);
      End loop;
      For reg in a90 loop
        LP_INS_REG_LIQUIDEZ(p_fec_actual,
                            'CREDITOS VIGENTES SECTOR FINANCIERO',
                            V_MONEDA,
                            reg.nro_cuenta,
                            reg.mto_dev,
                            reg.saldo,
                            90);
        V_MEN_90_DIAS := nvl(V_MEN_90_DIAS, 0) + nvl(reg.saldo, 0) +
                         nvl(reg.mto_dev, 0);
      End loop;
      For reg in a180 loop
        LP_INS_REG_LIQUIDEZ(p_fec_actual,
                            'CREDITOS VIGENTES SECTOR FINANCIERO',
                            V_MONEDA,
                            reg.nro_cuenta,
                            reg.mto_dev,
                            reg.saldo,
                            180);
        V_MEN_180_DIAS := nvl(V_MEN_180_DIAS, 0) + nvl(reg.saldo, 0) +
                          nvl(reg.mto_dev, 0);
      End loop;
      For reg in a365 loop
        LP_INS_REG_LIQUIDEZ(p_fec_actual,
                            'CREDITOS VIGENTES SECTOR FINANCIERO',
                            V_MONEDA,
                            reg.nro_cuenta,
                            reg.mto_dev,
                            reg.saldo,
                            365);
        V_MEN_1_ANO := nvl(V_MEN_1_ANO, 0) + nvl(reg.saldo, 0) +
                       nvl(reg.mto_dev, 0);
      End loop;
      For reg in a1095 loop
        LP_INS_REG_LIQUIDEZ(p_fec_actual,
                            'CREDITOS VIGENTES SECTOR FINANCIERO',
                            V_MONEDA,
                            reg.nro_cuenta,
                            reg.mto_dev,
                            reg.saldo,
                            1095);
        V_MEN_3_ANOS := nvl(V_MEN_3_ANOS, 0) + nvl(reg.saldo, 0) +
                        nvl(reg.mto_dev, 0);
      End loop;
      For reg in m1095 loop
        LP_INS_REG_LIQUIDEZ(p_fec_actual,
                            'CREDITOS VIGENTES SECTOR FINANCIERO',
                            V_MONEDA,
                            reg.nro_cuenta,
                            reg.mto_dev,
                            reg.saldo,
                            1096);
        V_MAY_3_ANOS := nvl(V_MAY_3_ANOS, 0) + nvl(reg.saldo, 0) +
                        nvl(reg.mto_dev, 0);
      End loop;
      insert into sb_liquidez
        (FECHA,
         COD_MONEDA,
         CUENTA,
         DESCRIPCION,
         PLZ_VISTA,
         MEN_30_DIAS,
         MEN_90_DIAS,
         MEN_180_DIAS,
         MEN_1_ANO,
         MEN_3_ANOS,
         MAY_3_ANOS)
      values
        (p_fec_actual,
         V_MONEDA,
         13000000000000,
         'CREDITOS VIGENTES SECTOR FINANCIERO',
         v_sal_actual,
         v_men_30_dias,
         v_men_90_dias,
         v_men_180_dias,
         v_men_1_ano,
         v_men_3_anos,
         v_may_3_anos);

      -- Sector No Financiero --
      V_SAL_ACTUAL   := 0;
      V_MEN_30_DIAS  := 0;
      V_MEN_90_DIAS  := 0;
      V_MEN_180_DIAS := 0;
      V_MEN_1_ANO    := 0;
      V_MEN_3_ANOS   := 0;
      V_MAY_3_ANOS   := 0;
      For reg in nfin loop
        LP_INS_REG_LIQUIDEZ(p_fec_actual,
                            'CREDITOS VIGENTES SECTOR NO FINANCIERO',
                            V_MONEDA,
                            reg.nro_cuenta,
                            0,
                            reg.saldo,
                            1);
        V_SAL_ACTUAL := nvl(V_SAL_ACTUAL, 0) + nvl(reg.saldo, 0);
      End loop;
      For reg in nmen30 loop
        LP_INS_REG_LIQUIDEZ(p_fec_actual,
                            'CREDITOS VIGENTES SECTOR NO FINANCIERO',
                            V_MONEDA,
                            reg.nro_cuenta,
                            reg.mto_dev,
                            reg.saldo,
                            30);
        V_MEN_30_DIAS := nvl(V_MEN_30_DIAS, 0) + nvl(reg.saldo, 0) +
                         nvl(reg.mto_dev, 0);
      End loop;
      For reg in na90 loop
        LP_INS_REG_LIQUIDEZ(p_fec_actual,
                            'CREDITOS VIGENTES SECTOR NO FINANCIERO',
                            V_MONEDA,
                            reg.nro_cuenta,
                            reg.mto_dev,
                            reg.saldo,
                            90);
        V_MEN_90_DIAS := nvl(V_MEN_90_DIAS, 0) + nvl(reg.saldo, 0) +
                         nvl(reg.mto_dev, 0);
      End loop;
      For reg in na180 loop
        LP_INS_REG_LIQUIDEZ(p_fec_actual,
                            'CREDITOS VIGENTES SECTOR NO FINANCIERO',
                            V_MONEDA,
                            reg.nro_cuenta,
                            reg.mto_dev,
                            reg.saldo,
                            180);
        V_MEN_180_DIAS := nvl(V_MEN_180_DIAS, 0) + nvl(reg.saldo, 0) +
                          nvl(reg.mto_dev, 0);
      End loop;
      For reg in na365 loop
        LP_INS_REG_LIQUIDEZ(p_fec_actual,
                            'CREDITOS VIGENTES SECTOR NO FINANCIERO',
                            V_MONEDA,
                            reg.nro_cuenta,
                            reg.mto_dev,
                            reg.saldo,
                            365);
        V_MEN_1_ANO := nvl(V_MEN_1_ANO, 0) + nvl(reg.saldo, 0) +
                       nvl(reg.mto_dev, 0);
      End loop;
      For reg in na1095 loop
        LP_INS_REG_LIQUIDEZ(p_fec_actual,
                            'CREDITOS VIGENTES SECTOR NO FINANCIERO',
                            V_MONEDA,
                            reg.nro_cuenta,
                            reg.mto_dev,
                            reg.saldo,
                            1095);
        V_MEN_3_ANOS := nvl(V_MEN_3_ANOS, 0) + nvl(reg.saldo, 0) +
                        nvl(reg.mto_dev, 0);
      End loop;
      For reg in nm1095 loop
        LP_INS_REG_LIQUIDEZ(p_fec_actual,
                            'CREDITOS VIGENTES SECTOR NO FINANCIERO',
                            V_MONEDA,
                            reg.nro_cuenta,
                            reg.mto_dev,
                            reg.saldo,
                            1096);
        V_MAY_3_ANOS := nvl(V_MAY_3_ANOS, 0) + nvl(reg.saldo, 0) +
                        nvl(reg.mto_dev, 0);
      End loop;
      insert into sb_liquidez
        (FECHA,
         COD_MONEDA,
         CUENTA,
         DESCRIPCION,
         PLZ_VISTA,
         MEN_30_DIAS,
         MEN_90_DIAS,
         MEN_180_DIAS,
         MEN_1_ANO,
         MEN_3_ANOS,
         MAY_3_ANOS)
      values
        (p_fec_actual,
         V_MONEDA,
         14000000000000,
         'CREDITOS VIGENTES SECTOR NO FINANCIERO',
         v_sal_actual,
         v_men_30_dias,
         v_men_90_dias,
         v_men_180_dias,
         v_men_1_ano,
         v_men_3_anos,
         v_may_3_anos);
    END;
    /* Calcula la liquidez préstamos para moneda local */
    PROCEDURE LP_CAL_LIQ_MONLOC_PR(P_FEC_ACTUAL IN DATE) IS

      V_SAL_ACTUAL2  NUMBER(18, 2);
      V_SAL_ACTUAL1  NUMBER(18, 2);
      V_SAL_ACTUAL   NUMBER(18, 2);
      V_MEN_30_DIAS  NUMBER(18, 2);
      V_MEN_90_DIAS  NUMBER(18, 2);
      V_MEN_180_DIAS NUMBER(18, 2);
      V_MEN_1_ANO    NUMBER(18, 2);
      V_MEN_3_ANOS   NUMBER(18, 2);
      V_MAY_3_ANOS   NUMBER(18, 2);
      V_CUENTA       VARCHAR2(15);
      V_MONEDA       AH_CTA_CERTIFICADOS.COD_MONEDA%TYPE;
      -- MONEDA LOCAL --
      --plazos vistas vencidos menor a hoy
      Cursor fin is
        select pr.nro_cuenta, round(nvl((pr.sal_cap_batch), 0), 0) saldo
          from pr_cta_prestamos pr, ge_cta_clientes ct, ge_clientes cl
         where pr.est_batch in ('C', 'A') --C=Vigente,A=Vigente c/atraso
           and pr.fec_vencimiento < p_fec_actual --ya vencidos
           and pr.cod_moneda = V_MONEDA
           and pr.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and ct.cod_persona = cl.cod_persona
           and cl.cod_sec_contable IN ('F', 'P', 'I'); --- Financiero y Publico

      -- Menores a 30 días
      Cursor men30 is
        select pr.nro_cuenta,
               round(nvl((pr.sal_cap_batch), 0), 0) saldo,
               round(nvl((dev_acumulado), 0), 0) mto_dev
          from pr_cta_prestamos pr, ge_cta_clientes ct, ge_clientes cl
         where pr.fec_vencimiento - p_fec_actual between 1 and 30 --q venzan a partir de mañana
           and pr.est_batch in ('C', 'A') --C=Vigente,A=Vigente c/atraso
           and pr.cod_moneda = V_MONEDA
           and pr.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and ct.cod_persona = cl.cod_persona
           and cl.cod_sec_contable IN ('F', 'P', 'I'); --- Financiero y Publico

      -- De 31 a 90 días
      Cursor a90 is
        select pr.nro_cuenta,
               round(nvl((pr.sal_cap_batch), 0), 0) saldo,
               round(nvl((dev_acumulado), 0), 0) mto_dev
          from pr_cta_prestamos pr, ge_cta_clientes ct, ge_clientes cl
         where pr.fec_vencimiento - p_fec_actual between 31 and 90
           and pr.est_batch in ('C', 'A') --C=Vigente,A=Vigente c/atraso
           and pr.cod_moneda = V_MONEDA
           and pr.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and ct.cod_persona = cl.cod_persona
           and cl.cod_sec_contable IN ('F', 'P', 'I'); --- Financiero y Publico

      -- De 91 a 180 dias
      Cursor a180 is
        select pr.nro_cuenta,
               round(nvl((pr.sal_cap_batch), 0), 0) saldo,
               round(nvl((dev_acumulado), 0), 0) mto_dev
          from pr_cta_prestamos pr, ge_cta_clientes ct, ge_clientes cl
         where pr.fec_vencimiento - p_fec_actual between 91 and 180
           and pr.est_batch in ('C', 'A') --C=Vigente,A=Vigente c/atraso
           and pr.cod_moneda = V_MONEDA
           and pr.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and ct.cod_persona = cl.cod_persona
           and cl.cod_sec_contable IN ('F', 'P', 'I'); --- Financiero y Publico

      -- De 181 a 365 dias
      Cursor a365 is
        select pr.nro_cuenta,
               round(nvl((pr.sal_cap_batch), 0), 0) saldo,
               round(nvl((dev_acumulado), 0), 0) mto_dev
          from pr_cta_prestamos pr, ge_cta_clientes ct, ge_clientes cl
         where pr.fec_vencimiento - p_fec_actual between 181 and 365
           and pr.est_batch in ('C', 'A') --C=Vigente,A=Vigente c/atraso
           and pr.cod_moneda = V_MONEDA
           and pr.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and ct.cod_persona = cl.cod_persona
           and cl.cod_sec_contable IN ('F', 'P', 'I'); --- Financiero y Publico

      -- De 365 a 1095 dias(3 años)
      Cursor a1095 is
        select pr.nro_cuenta,
               round(nvl((pr.sal_cap_batch), 0), 0) saldo,
               round(nvl((dev_acumulado), 0), 0) mto_dev
          from pr_cta_prestamos pr, ge_cta_clientes ct, ge_clientes cl
         where pr.fec_vencimiento - p_fec_actual between 366 and 1095
           and pr.est_batch in ('C', 'A') --C=Vigente,A=Vigente c/atraso
           and pr.cod_moneda = V_MONEDA
           and pr.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and ct.cod_persona = cl.cod_persona
           and cl.cod_sec_contable IN ('F', 'P', 'I'); --- Financiero y Publico

      -- Mayor 1095 dias(3 años)
      Cursor m1095 is
        select pr.nro_cuenta,
               round(nvl((pr.sal_cap_batch), 0), 0) saldo,
               round(nvl((dev_acumulado), 0), 0) mto_dev
          from pr_cta_prestamos pr, ge_cta_clientes ct, ge_clientes cl
         where pr.fec_vencimiento - p_fec_actual > 1095
           and pr.est_batch in ('C', 'A') --C=Vigente,A=Vigente c/atraso
           and pr.cod_moneda = V_MONEDA
           and pr.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and ct.cod_persona = cl.cod_persona
           and cl.cod_sec_contable IN ('F', 'P', 'I'); --- Financiero y Publico

      --sector no financiero
      Cursor nfin is
        select pr.nro_cuenta, round(nvl((pr.sal_cap_batch), 0), 0) saldo
          from pr_cta_prestamos pr, ge_cta_clientes ct, ge_clientes cl
         where pr.est_batch in ('C', 'A') --C=Vigente,A=Vigente c/atraso
           and pr.fec_vencimiento < p_fec_actual --ya vencidos
           and pr.cod_moneda = V_MONEDA
           and pr.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and ct.cod_persona = cl.cod_persona
           and cl.cod_sec_contable = 'N';

      -- Menores a 30 días
      Cursor nmen30 is
        select pr.nro_cuenta,
               round(nvl((pr.sal_cap_batch), 0), 0) saldo,
               round(nvl((dev_acumulado), 0), 0) mto_dev
          from pr_cta_prestamos pr, ge_cta_clientes ct, ge_clientes cl
         where pr.fec_vencimiento - p_fec_actual between 1 and 30 --q venzan a partir de mañana
           and pr.est_batch in ('C', 'A') --C=Vigente,A=Vigente c/atraso
           and pr.cod_moneda = V_MONEDA
           and pr.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and ct.cod_persona = cl.cod_persona
           and cl.cod_sec_contable = 'N';

      -- De 31 a 90 días
      Cursor na90 is
        select pr.nro_cuenta,
               round(nvl((pr.sal_cap_batch), 0), 0) saldo,
               round(nvl((dev_acumulado), 0), 0) mto_dev
          from pr_cta_prestamos pr, ge_cta_clientes ct, ge_clientes cl
         where pr.fec_vencimiento - p_fec_actual between 31 and 90
           and pr.est_batch in ('C', 'A') --C=Vigente,A=Vigente c/atraso
           and pr.cod_moneda = V_MONEDA
           and pr.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and ct.cod_persona = cl.cod_persona
           and cl.cod_sec_contable = 'N';

      -- De 91 a 180 dias
      Cursor na180 is
        select pr.nro_cuenta,
               round(nvl((pr.sal_cap_batch), 0), 0) saldo,
               round(nvl((dev_acumulado), 0), 0) mto_dev
          from pr_cta_prestamos pr, ge_cta_clientes ct, ge_clientes cl
         where pr.fec_vencimiento - p_fec_actual between 91 and 180
           and pr.est_batch in ('C', 'A') --C=Vigente,A=Vigente c/atraso
           and pr.cod_moneda = V_MONEDA
           and pr.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and ct.cod_persona = cl.cod_persona
           and cl.cod_sec_contable = 'N';

      -- De 181 a 365 dias
      Cursor na365 is
        select pr.nro_cuenta,
               round(nvl((pr.sal_cap_batch), 0), 0) saldo,
               round(nvl((dev_acumulado), 0), 0) mto_dev
          from pr_cta_prestamos pr, ge_cta_clientes ct, ge_clientes cl
         where pr.fec_vencimiento - p_fec_actual between 181 and 365
           and pr.est_batch in ('C', 'A') --C=Vigente,A=Vigente c/atraso
           and pr.cod_moneda = V_MONEDA
           and pr.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and ct.cod_persona = cl.cod_persona
           and cl.cod_sec_contable = 'N';

      -- De 365 a 1095 dias(3 años)
      Cursor na1095 is
        select pr.nro_cuenta,
               round(nvl((pr.sal_cap_batch), 0), 0) saldo,
               round(nvl((dev_acumulado), 0), 0) mto_dev
          from pr_cta_prestamos pr, ge_cta_clientes ct, ge_clientes cl
         where pr.fec_vencimiento - p_fec_actual between 366 and 1095
           and pr.est_batch in ('C', 'A') --C=Vigente,A=Vigente c/atraso
           and pr.cod_moneda = V_MONEDA
           and pr.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and ct.cod_persona = cl.cod_persona
           and cl.cod_sec_contable = 'N';

      -- Mayor 1095 dias(3 años)
      Cursor nm1095 is
        select pr.nro_cuenta,
               round(nvl((pr.sal_cap_batch), 0), 0) saldo,
               round(nvl((dev_acumulado), 0), 0) mto_dev
          from pr_cta_prestamos pr, ge_cta_clientes ct, ge_clientes cl
         where pr.fec_vencimiento - p_fec_actual > 1095
           and pr.est_batch in ('C', 'A') --C=Vigente,A=Vigente c/atraso
           and pr.cod_moneda = V_MONEDA
           and pr.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and ct.cod_persona = cl.cod_persona
           and cl.cod_sec_contable = 'N';
    BEGIN
      V_MONEDA := pag_gen.fu_obt_mon_local;
      -- Sector Financiero --
      V_SAL_ACTUAL   := 0;
      V_MEN_30_DIAS  := 0;
      V_MEN_90_DIAS  := 0;
      V_MEN_180_DIAS := 0;
      V_MEN_1_ANO    := 0;
      V_MEN_3_ANOS   := 0;
      V_MAY_3_ANOS   := 0;
      For reg in fin loop
        LP_INS_REG_LIQUIDEZ(p_fec_actual,
                            'CREDITOS VIGENTES SECTOR FINANCIERO',
                            V_MONEDA,
                            reg.nro_cuenta,
                            0,
                            reg.saldo,
                            1);
        V_SAL_ACTUAL := nvl(V_SAL_ACTUAL, 0) + nvl(reg.saldo, 0);
      End loop;
      For reg in men30 loop
        LP_INS_REG_LIQUIDEZ(p_fec_actual,
                            'CREDITOS VIGENTES SECTOR FINANCIERO',
                            V_MONEDA,
                            reg.nro_cuenta,
                            reg.mto_dev,
                            reg.saldo,
                            30);
        V_MEN_30_DIAS := nvl(V_MEN_30_DIAS, 0) + nvl(reg.saldo, 0) +
                         nvl(reg.mto_dev, 0);
      End loop;
      For reg in a90 loop
        LP_INS_REG_LIQUIDEZ(p_fec_actual,
                            'CREDITOS VIGENTES SECTOR FINANCIERO',
                            V_MONEDA,
                            reg.nro_cuenta,
                            reg.mto_dev,
                            reg.saldo,
                            90);
        V_MEN_90_DIAS := nvl(V_MEN_90_DIAS, 0) + nvl(reg.saldo, 0) +
                         nvl(reg.mto_dev, 0);
      End loop;
      For reg in a180 loop
        LP_INS_REG_LIQUIDEZ(p_fec_actual,
                            'CREDITOS VIGENTES SECTOR FINANCIERO',
                            V_MONEDA,
                            reg.nro_cuenta,
                            reg.mto_dev,
                            reg.saldo,
                            180);
        V_MEN_180_DIAS := nvl(V_MEN_180_DIAS, 0) + nvl(reg.saldo, 0) +
                          nvl(reg.mto_dev, 0);
      End loop;
      For reg in a365 loop
        LP_INS_REG_LIQUIDEZ(p_fec_actual,
                            'CREDITOS VIGENTES SECTOR FINANCIERO',
                            V_MONEDA,
                            reg.nro_cuenta,
                            reg.mto_dev,
                            reg.saldo,
                            365);
        V_MEN_1_ANO := nvl(V_MEN_1_ANO, 0) + nvl(reg.saldo, 0) +
                       nvl(reg.mto_dev, 0);
      End loop;
      For reg in a1095 loop
        LP_INS_REG_LIQUIDEZ(p_fec_actual,
                            'CREDITOS VIGENTES SECTOR FINANCIERO',
                            V_MONEDA,
                            reg.nro_cuenta,
                            reg.mto_dev,
                            reg.saldo,
                            1095);
        V_MEN_3_ANOS := nvl(V_MEN_3_ANOS, 0) + nvl(reg.saldo, 0) +
                        nvl(reg.mto_dev, 0);
      End loop;
      For reg in m1095 loop
        LP_INS_REG_LIQUIDEZ(p_fec_actual,
                            'CREDITOS VIGENTES SECTOR FINANCIERO',
                            V_MONEDA,
                            reg.nro_cuenta,
                            reg.mto_dev,
                            reg.saldo,
                            1096);
        V_MAY_3_ANOS := nvl(V_MAY_3_ANOS, 0) + nvl(reg.saldo, 0) +
                        nvl(reg.mto_dev, 0);
      End loop;
      insert into sb_liquidez
        (FECHA,
         COD_MONEDA,
         CUENTA,
         DESCRIPCION,
         PLZ_VISTA,
         MEN_30_DIAS,
         MEN_90_DIAS,
         MEN_180_DIAS,
         MEN_1_ANO,
         MEN_3_ANOS,
         MAY_3_ANOS)
      values
        (p_fec_actual,
         V_MONEDA,
         13000000000000,
         'CREDITOS VIGENTES SECTOR FINANCIERO',
         v_sal_actual,
         v_men_30_dias,
         v_men_90_dias,
         v_men_180_dias,
         v_men_1_ano,
         v_men_3_anos,
         v_may_3_anos);

      -- Sector No Financiero --
      V_SAL_ACTUAL   := 0;
      V_MEN_30_DIAS  := 0;
      V_MEN_90_DIAS  := 0;
      V_MEN_180_DIAS := 0;
      V_MEN_1_ANO    := 0;
      V_MEN_3_ANOS   := 0;
      V_MAY_3_ANOS   := 0;
      For reg in nfin loop
        LP_INS_REG_LIQUIDEZ(p_fec_actual,
                            'CREDITOS VIGENTES SECTOR NO FINANCIERO',
                            V_MONEDA,
                            reg.nro_cuenta,
                            0,
                            reg.saldo,
                            1);
        V_SAL_ACTUAL := nvl(V_SAL_ACTUAL, 0) + nvl(reg.saldo, 0);
      End loop;
      For reg in nmen30 loop
        LP_INS_REG_LIQUIDEZ(p_fec_actual,
                            'CREDITOS VIGENTES SECTOR NO FINANCIERO',
                            V_MONEDA,
                            reg.nro_cuenta,
                            reg.mto_dev,
                            reg.saldo,
                            30);
        V_MEN_30_DIAS := nvl(V_MEN_30_DIAS, 0) + nvl(reg.saldo, 0) +
                         nvl(reg.mto_dev, 0);
      End loop;
      For reg in na90 loop
        LP_INS_REG_LIQUIDEZ(p_fec_actual,
                            'CREDITOS VIGENTES SECTOR NO FINANCIERO',
                            V_MONEDA,
                            reg.nro_cuenta,
                            reg.mto_dev,
                            reg.saldo,
                            90);
        V_MEN_90_DIAS := nvl(V_MEN_90_DIAS, 0) + nvl(reg.saldo, 0) +
                         nvl(reg.mto_dev, 0);
      End loop;
      For reg in na180 loop
        LP_INS_REG_LIQUIDEZ(p_fec_actual,
                            'CREDITOS VIGENTES SECTOR NO FINANCIERO',
                            V_MONEDA,
                            reg.nro_cuenta,
                            reg.mto_dev,
                            reg.saldo,
                            180);
        V_MEN_180_DIAS := nvl(V_MEN_180_DIAS, 0) + nvl(reg.saldo, 0) +
                          nvl(reg.mto_dev, 0);
      End loop;
      For reg in na365 loop
        LP_INS_REG_LIQUIDEZ(p_fec_actual,
                            'CREDITOS VIGENTES SECTOR NO FINANCIERO',
                            V_MONEDA,
                            reg.nro_cuenta,
                            reg.mto_dev,
                            reg.saldo,
                            365);
        V_MEN_1_ANO := nvl(V_MEN_1_ANO, 0) + nvl(reg.saldo, 0) +
                       nvl(reg.mto_dev, 0);
      End loop;
      For reg in na1095 loop
        LP_INS_REG_LIQUIDEZ(p_fec_actual,
                            'CREDITOS VIGENTES SECTOR NO FINANCIERO',
                            V_MONEDA,
                            reg.nro_cuenta,
                            reg.mto_dev,
                            reg.saldo,
                            1095);
        V_MEN_3_ANOS := nvl(V_MEN_3_ANOS, 0) + nvl(reg.saldo, 0) +
                        nvl(reg.mto_dev, 0);
      End loop;
      For reg in nm1095 loop
        LP_INS_REG_LIQUIDEZ(p_fec_actual,
                            'CREDITOS VIGENTES SECTOR NO FINANCIERO',
                            V_MONEDA,
                            reg.nro_cuenta,
                            reg.mto_dev,
                            reg.saldo,
                            1096);
        V_MAY_3_ANOS := nvl(V_MAY_3_ANOS, 0) + nvl(reg.saldo, 0) +
                        nvl(reg.mto_dev, 0);
      End loop;
      insert into sb_liquidez
        (FECHA,
         COD_MONEDA,
         CUENTA,
         DESCRIPCION,
         PLZ_VISTA,
         MEN_30_DIAS,
         MEN_90_DIAS,
         MEN_180_DIAS,
         MEN_1_ANO,
         MEN_3_ANOS,
         MAY_3_ANOS)
      values
        (p_fec_actual,
         V_MONEDA,
         14000000000000,
         'CREDITOS VIGENTES SECTOR NO FINANCIERO',
         v_sal_actual,
         v_men_30_dias,
         v_men_90_dias,
         v_men_180_dias,
         v_men_1_ano,
         v_men_3_anos,
         v_may_3_anos);
    END;
    /* Calcula la liquidez préstamos por cuota moneda extranjera */
    PROCEDURE LP_LIQ_CUO_MONEXT_PR(P_FEC_ACTUAL IN DATE) IS

      V_SAL_ACTUAL2  NUMBER(18, 2);
      V_SAL_ACTUAL1  NUMBER(18, 2);
      V_SAL_ACTUAL   NUMBER(18, 2);
      V_MEN_30_DIAS  NUMBER(18, 2);
      V_MEN_90_DIAS  NUMBER(18, 2);
      V_MEN_180_DIAS NUMBER(18, 2);
      V_MEN_1_ANO    NUMBER(18, 2);
      V_MEN_3_ANOS   NUMBER(18, 2);
      V_MAY_3_ANOS   NUMBER(18, 2);
      V_CUENTA       VARCHAR2(15);
      V_MONEDA       AH_CTA_CERTIFICADOS.COD_MONEDA%TYPE;
      -- MONEDA EXTRANJERA --
      --sector financiero
      --plazos vistas vencidos menor a hoy
      Cursor fin is
        select pr.nro_cuenta,
               sum(nvl(pr.sal_capital, 0)) saldo,
               sum(nvl(pr.dev_no_cobrado, 0)) mto_dev,
               sum(nvl(pr.mto_prevision, 0)) mto_prevision
          from sb_liq_cuotas    pr,
               ge_cta_clientes  ct,
               ge_clientes      cl,
               pr_cta_prestamos x
         where pr.fec_vencimiento <= p_fec_actual --ya vencidos
           and pr.cod_moneda = v_moneda
           and pr.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and ct.cod_persona = cl.cod_persona
           and cl.cod_sec_contable IN ('F', 'P', 'I') --- Financiero y Publico
           and x.nro_cuenta = ct.nro_cuenta
           and x.est_batch in ('C', 'A') --Vigente, y Vig. c/Atraso--
         group by pr.nro_cuenta;

      -- Menores a 30 días
      Cursor men30 is
        select pr.nro_cuenta,
               sum(nvl(pr.sal_capital, 0)) saldo,
               sum(nvl(pr.dev_no_cobrado, 0)) mto_dev,
               sum(nvl(pr.mto_prevision, 0)) mto_prevision
          from sb_liq_cuotas    pr,
               ge_cta_clientes  ct,
               ge_clientes      cl,
               pr_cta_prestamos x
         where pr.fec_vencimiento - p_fec_actual between 1 and 30 --q venzan a partir de mañana
           and pr.cod_moneda = v_moneda
           and pr.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and ct.cod_persona = cl.cod_persona
           and cl.cod_sec_contable IN ('F', 'P', 'I') --- Financiero y Publico
           and x.nro_cuenta = ct.nro_cuenta
           and x.est_batch in ('C', 'A') --Vigente, y Vig. c/Atraso--
         group by pr.nro_cuenta;

      -- De 31 a 90 días
      Cursor a90 is
        select pr.nro_cuenta,
               sum(nvl(pr.sal_capital, 0)) saldo,
               sum(nvl(pr.dev_no_cobrado, 0)) mto_dev,
               sum(nvl(pr.mto_prevision, 0)) mto_prevision
          from sb_liq_cuotas    pr,
               ge_cta_clientes  ct,
               ge_clientes      cl,
               pr_cta_prestamos x
         where pr.fec_vencimiento - p_fec_actual between 31 and 90
           and pr.cod_moneda = v_moneda
           and pr.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and ct.cod_persona = cl.cod_persona
           and cl.cod_sec_contable IN ('F', 'P', 'I') --- Financiero y Publico
           and x.nro_cuenta = ct.nro_cuenta
           and x.est_batch in ('C', 'A') --Vigente, y Vig. c/Atraso--
         group by pr.nro_cuenta;

      -- De 91 a 180 dias
      Cursor a180 is
        select pr.nro_cuenta,
               sum(nvl(pr.sal_capital, 0)) saldo,
               sum(nvl(pr.dev_no_cobrado, 0)) mto_dev,
               sum(nvl(pr.mto_prevision, 0)) mto_prevision
          from sb_liq_cuotas    pr,
               ge_cta_clientes  ct,
               ge_clientes      cl,
               pr_cta_prestamos x
         where pr.fec_vencimiento - p_fec_actual between 91 and 180
           and pr.cod_moneda = v_moneda
           and pr.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and ct.cod_persona = cl.cod_persona
           and cl.cod_sec_contable IN ('F', 'P', 'I') --- Financiero y Publico
           and x.nro_cuenta = ct.nro_cuenta
           and x.est_batch in ('C', 'A') --Vigente, y Vig. c/Atraso--
         group by pr.nro_cuenta;

      -- De 181 a 365 dias
      Cursor a365 is
        select pr.nro_cuenta,
               sum(nvl(pr.sal_capital, 0)) saldo,
               sum(nvl(pr.dev_no_cobrado, 0)) mto_dev,
               sum(nvl(pr.mto_prevision, 0)) mto_prevision
          from sb_liq_cuotas    pr,
               ge_cta_clientes  ct,
               ge_clientes      cl,
               pr_cta_prestamos x
         where pr.fec_vencimiento - p_fec_actual between 181 and 365
           and pr.cod_moneda = v_moneda
           and pr.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and ct.cod_persona = cl.cod_persona
           and cl.cod_sec_contable IN ('F', 'P', 'I') --- Financiero y Publico
           and x.nro_cuenta = ct.nro_cuenta
           and x.est_batch in ('C', 'A') --Vigente, y Vig. c/Atraso--
         group by pr.nro_cuenta;

      -- De 365 a 1095 dias(3 años)
      Cursor a1095 is
        select pr.nro_cuenta,
               sum(nvl(pr.sal_capital, 0)) saldo,
               sum(nvl(pr.dev_no_cobrado, 0)) mto_dev,
               sum(nvl(pr.mto_prevision, 0)) mto_prevision
          from sb_liq_cuotas    pr,
               ge_cta_clientes  ct,
               ge_clientes      cl,
               pr_cta_prestamos x
         where pr.fec_vencimiento - p_fec_actual between 366 and 1095
           and pr.cod_moneda = v_moneda
           and pr.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and ct.cod_persona = cl.cod_persona
           and cl.cod_sec_contable IN ('F', 'P', 'I') --- Financiero y Publico
           and x.nro_cuenta = ct.nro_cuenta
           and x.est_batch in ('C', 'A') --Vigente, y Vig. c/Atraso--
         group by pr.nro_cuenta;

      -- Mayor 1095 dias(3 años)
      Cursor m1095 is
        select pr.nro_cuenta,
               sum(nvl(pr.sal_capital, 0)) saldo,
               sum(nvl(pr.dev_no_cobrado, 0)) mto_dev,
               sum(nvl(pr.mto_prevision, 0)) mto_prevision
          from sb_liq_cuotas    pr,
               ge_cta_clientes  ct,
               ge_clientes      cl,
               pr_cta_prestamos x
         where pr.fec_vencimiento - p_fec_actual > 1095
           and pr.cod_moneda = v_moneda
           and pr.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and ct.cod_persona = cl.cod_persona
           and cl.cod_sec_contable IN ('F', 'P', 'I') --- Financiero y Publico
           and x.nro_cuenta = ct.nro_cuenta
           and x.est_batch in ('C', 'A') --Vigente, y Vig. c/Atraso--
         group by pr.nro_cuenta;

      --sector no financiero
      Cursor nfin is
        select pr.nro_cuenta,
               sum(nvl(pr.sal_capital, 0)) saldo,
               sum(nvl(pr.dev_no_cobrado, 0)) mto_dev,
               sum(nvl(pr.mto_prevision, 0)) mto_prevision
          from sb_liq_cuotas    pr,
               ge_cta_clientes  ct,
               ge_clientes      cl,
               pr_cta_prestamos x
         where pr.fec_vencimiento <= p_fec_actual --ya vencidos
           and pr.cod_moneda = v_moneda
           and pr.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and ct.cod_persona = cl.cod_persona
           and cl.cod_sec_contable = 'N'
           and x.nro_cuenta = ct.nro_cuenta
           and x.est_batch in ('C', 'A') --Vigente, y Vig. c/Atraso--
         group by pr.nro_cuenta;

      -- Menores a 30 días
      Cursor nmen30 is
        select pr.nro_cuenta,
               sum(nvl(pr.sal_capital, 0)) saldo,
               sum(nvl(pr.dev_no_cobrado, 0)) mto_dev,
               sum(nvl(pr.mto_prevision, 0)) mto_prevision
          from sb_liq_cuotas    pr,
               ge_cta_clientes  ct,
               ge_clientes      cl,
               pr_cta_prestamos x
         where pr.fec_vencimiento - p_fec_actual between 1 and 30 --q venzan a partir de mañana
           and pr.cod_moneda = v_moneda
           and pr.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and ct.cod_persona = cl.cod_persona
           and cl.cod_sec_contable = 'N'
           and x.nro_cuenta = ct.nro_cuenta
           and x.est_batch in ('C', 'A') --Vigente, y Vig. c/Atraso--
         group by pr.nro_cuenta;

      -- De 31 a 90 días
      Cursor na90 is
        select pr.nro_cuenta,
               sum(nvl(pr.sal_capital, 0)) saldo,
               sum(nvl(pr.dev_no_cobrado, 0)) mto_dev,
               sum(nvl(pr.mto_prevision, 0)) mto_prevision
          from sb_liq_cuotas    pr,
               ge_cta_clientes  ct,
               ge_clientes      cl,
               pr_cta_prestamos x
         where pr.fec_vencimiento - p_fec_actual between 31 and 90
           and pr.cod_moneda = v_moneda
           and pr.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and ct.cod_persona = cl.cod_persona
           and cl.cod_sec_contable = 'N'
           and x.nro_cuenta = ct.nro_cuenta
           and x.est_batch in ('C', 'A') --Vigente, y Vig. c/Atraso--
         group by pr.nro_cuenta;

      -- De 91 a 180 dias
      Cursor na180 is
        select pr.nro_cuenta,
               sum(nvl(pr.sal_capital, 0)) saldo,
               sum(nvl(pr.dev_no_cobrado, 0)) mto_dev,
               sum(nvl(pr.mto_prevision, 0)) mto_prevision
          from sb_liq_cuotas    pr,
               ge_cta_clientes  ct,
               ge_clientes      cl,
               pr_cta_prestamos x
         where pr.fec_vencimiento - p_fec_actual between 91 and 180
           and pr.cod_moneda = v_moneda
           and pr.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and ct.cod_persona = cl.cod_persona
           and cl.cod_sec_contable = 'N'
           and x.nro_cuenta = ct.nro_cuenta
           and x.est_batch in ('C', 'A') --Vigente, y Vig. c/Atraso--
         group by pr.nro_cuenta;

      -- De 181 a 365 dias
      Cursor na365 is
        select pr.nro_cuenta,
               sum(nvl(pr.sal_capital, 0)) saldo,
               sum(nvl(pr.dev_no_cobrado, 0)) mto_dev,
               sum(nvl(pr.mto_prevision, 0)) mto_prevision
          from sb_liq_cuotas    pr,
               ge_cta_clientes  ct,
               ge_clientes      cl,
               pr_cta_prestamos x
         where pr.fec_vencimiento - p_fec_actual between 181 and 365
           and pr.cod_moneda = v_moneda
           and pr.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and ct.cod_persona = cl.cod_persona
           and cl.cod_sec_contable = 'N'
           and x.nro_cuenta = ct.nro_cuenta
           and x.est_batch in ('C', 'A') --Vigente, y Vig. c/Atraso--
         group by pr.nro_cuenta;

      -- De 365 a 1095 dias(3 años)
      Cursor na1095 is
        select pr.nro_cuenta,
               sum(nvl(pr.sal_capital, 0)) saldo,
               sum(nvl(pr.dev_no_cobrado, 0)) mto_dev,
               sum(nvl(pr.mto_prevision, 0)) mto_prevision
          from sb_liq_cuotas    pr,
               ge_cta_clientes  ct,
               ge_clientes      cl,
               pr_cta_prestamos x
         where pr.fec_vencimiento - p_fec_actual between 366 and 1095
           and pr.cod_moneda = v_moneda
           and pr.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and ct.cod_persona = cl.cod_persona
           and cl.cod_sec_contable = 'N'
           and x.nro_cuenta = ct.nro_cuenta
           and x.est_batch in ('C', 'A') --Vigente, y Vig. c/Atraso--
         group by pr.nro_cuenta;

      -- Mayor 1095 dias(3 años)
      Cursor nm1095 is
        select pr.nro_cuenta,
               sum(nvl(pr.sal_capital, 0)) saldo,
               sum(nvl(pr.dev_no_cobrado, 0)) mto_dev,
               sum(nvl(pr.mto_prevision, 0)) mto_prevision
          from sb_liq_cuotas    pr,
               ge_cta_clientes  ct,
               ge_clientes      cl,
               pr_cta_prestamos x
         where pr.fec_vencimiento - p_fec_actual > 1095
           and pr.cod_moneda = v_moneda
           and pr.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and ct.cod_persona = cl.cod_persona
           and cl.cod_sec_contable = 'N'
           and x.nro_cuenta = ct.nro_cuenta
           and x.est_batch in ('C', 'A') --Vigente, y Vig. c/Atraso--
         group by pr.nro_cuenta;
    BEGIN
      V_MONEDA := PAS_BCP.FU_OBT_MON_FUERTE;
      -- Sector Financiero --
      V_SAL_ACTUAL   := 0;
      V_MEN_30_DIAS  := 0;
      V_MEN_90_DIAS  := 0;
      V_MEN_180_DIAS := 0;
      V_MEN_1_ANO    := 0;
      V_MEN_3_ANOS   := 0;
      V_MAY_3_ANOS   := 0;

      For reg in fin loop
        LP_INS_REG_LIQUIDEZ(p_fec_actual,
                            'CREDITOS VIGENTES SECTOR FINANCIERO',
                            V_MONEDA,
                            reg.nro_cuenta,
                            reg.mto_dev,
                            reg.saldo,
                            1,
                            reg.mto_prevision);
        V_SAL_ACTUAL := nvl(V_SAL_ACTUAL, 0) +
                        (nvl(reg.saldo, 0) + nvl(reg.mto_dev, 0) -
                         nvl(reg.mto_prevision, 0));
      End loop;
      For reg in men30 loop
        LP_INS_REG_LIQUIDEZ(p_fec_actual,
                            'CREDITOS VIGENTES SECTOR FINANCIERO',
                            V_MONEDA,
                            reg.nro_cuenta,
                            reg.mto_dev,
                            reg.saldo,
                            30,
                            reg.mto_prevision);
        V_MEN_30_DIAS := nvl(V_MEN_30_DIAS, 0) +
                         (nvl(reg.saldo, 0) + nvl(reg.mto_dev, 0) -
                          nvl(reg.mto_prevision, 0));
      End loop;
      For reg in a90 loop
        LP_INS_REG_LIQUIDEZ(p_fec_actual,
                            'CREDITOS VIGENTES SECTOR FINANCIERO',
                            V_MONEDA,
                            reg.nro_cuenta,
                            reg.mto_dev,
                            reg.saldo,
                            90,
                            reg.mto_prevision);
        V_MEN_90_DIAS := nvl(V_MEN_90_DIAS, 0) +
                         (nvl(reg.saldo, 0) + nvl(reg.mto_dev, 0) -
                          nvl(reg.mto_prevision, 0));
      End loop;
      For reg in a180 loop
        LP_INS_REG_LIQUIDEZ(p_fec_actual,
                            'CREDITOS VIGENTES SECTOR FINANCIERO',
                            V_MONEDA,
                            reg.nro_cuenta,
                            reg.mto_dev,
                            reg.saldo,
                            180,
                            reg.mto_prevision);
        V_MEN_180_DIAS := nvl(V_MEN_180_DIAS, 0) +
                          (nvl(reg.saldo, 0) + nvl(reg.mto_dev, 0) -
                           nvl(reg.mto_prevision, 0));
      End loop;
      For reg in a365 loop
        LP_INS_REG_LIQUIDEZ(p_fec_actual,
                            'CREDITOS VIGENTES SECTOR FINANCIERO',
                            V_MONEDA,
                            reg.nro_cuenta,
                            reg.mto_dev,
                            reg.saldo,
                            365,
                            reg.mto_prevision);
        V_MEN_1_ANO := nvl(V_MEN_1_ANO, 0) +
                       (nvl(reg.saldo, 0) + nvl(reg.mto_dev, 0) -
                        nvl(reg.mto_prevision, 0));
      End loop;
      For reg in a1095 loop
        LP_INS_REG_LIQUIDEZ(p_fec_actual,
                            'CREDITOS VIGENTES SECTOR FINANCIERO',
                            V_MONEDA,
                            reg.nro_cuenta,
                            reg.mto_dev,
                            reg.saldo,
                            1095,
                            reg.mto_prevision);
        V_MEN_3_ANOS := nvl(V_MEN_3_ANOS, 0) +
                        (nvl(reg.saldo, 0) + nvl(reg.mto_dev, 0) -
                         nvl(reg.mto_prevision, 0));
      End loop;
      For reg in m1095 loop
        LP_INS_REG_LIQUIDEZ(p_fec_actual,
                            'CREDITOS VIGENTES SECTOR FINANCIERO',
                            V_MONEDA,
                            reg.nro_cuenta,
                            reg.mto_dev,
                            reg.saldo,
                            1096,
                            reg.mto_prevision);
        V_MAY_3_ANOS := nvl(V_MAY_3_ANOS, 0) +
                        (nvl(reg.saldo, 0) + nvl(reg.mto_dev, 0) -
                         nvl(reg.mto_prevision, 0));
      End loop;
      insert into sb_liquidez
        (FECHA,
         COD_MONEDA,
         CUENTA,
         DESCRIPCION,
         PLZ_VISTA,
         MEN_30_DIAS,
         MEN_90_DIAS,
         MEN_180_DIAS,
         MEN_1_ANO,
         MEN_3_ANOS,
         MAY_3_ANOS)
      values
        (p_fec_actual,
         V_MONEDA,
         13000000000000,
         'CREDITOS VIGENTES SECTOR FINANCIERO',
         v_sal_actual,
         v_men_30_dias,
         v_men_90_dias,
         v_men_180_dias,
         v_men_1_ano,
         v_men_3_anos,
         v_may_3_anos);

      -- Sector No Financiero --
      V_SAL_ACTUAL   := 0;
      V_MEN_30_DIAS  := 0;
      V_MEN_90_DIAS  := 0;
      V_MEN_180_DIAS := 0;
      V_MEN_1_ANO    := 0;
      V_MEN_3_ANOS   := 0;
      V_MAY_3_ANOS   := 0;
      For reg in nfin loop
        LP_INS_REG_LIQUIDEZ(p_fec_actual,
                            'CREDITOS VIGENTES SECTOR NO FINANCIERO',
                            V_MONEDA,
                            reg.nro_cuenta,
                            reg.mto_dev,
                            reg.saldo,
                            1,
                            reg.mto_prevision);
        V_SAL_ACTUAL := nvl(V_SAL_ACTUAL, 0) +
                        (nvl(reg.saldo, 0) + nvl(reg.mto_dev, 0) -
                         nvl(reg.mto_prevision, 0));
      End loop;
      For reg in nmen30 loop
        LP_INS_REG_LIQUIDEZ(p_fec_actual,
                            'CREDITOS VIGENTES SECTOR NO FINANCIERO',
                            V_MONEDA,
                            reg.nro_cuenta,
                            reg.mto_dev,
                            reg.saldo,
                            30,
                            reg.mto_prevision);
        V_MEN_30_DIAS := nvl(V_MEN_30_DIAS, 0) +
                         (nvl(reg.saldo, 0) + nvl(reg.mto_dev, 0) -
                          nvl(reg.mto_prevision, 0));
      End loop;
      For reg in na90 loop
        LP_INS_REG_LIQUIDEZ(p_fec_actual,
                            'CREDITOS VIGENTES SECTOR NO FINANCIERO',
                            V_MONEDA,
                            reg.nro_cuenta,
                            reg.mto_dev,
                            reg.saldo,
                            90,
                            reg.mto_prevision);
        V_MEN_90_DIAS := nvl(V_MEN_90_DIAS, 0) +
                         (nvl(reg.saldo, 0) + nvl(reg.mto_dev, 0) -
                          nvl(reg.mto_prevision, 0));
      End loop;
      For reg in na180 loop
        LP_INS_REG_LIQUIDEZ(p_fec_actual,
                            'CREDITOS VIGENTES SECTOR NO FINANCIERO',
                            V_MONEDA,
                            reg.nro_cuenta,
                            reg.mto_dev,
                            reg.saldo,
                            180,
                            reg.mto_prevision);
        V_MEN_180_DIAS := nvl(V_MEN_180_DIAS, 0) +
                          (nvl(reg.saldo, 0) + nvl(reg.mto_dev, 0) -
                           nvl(reg.mto_prevision, 0));
      End loop;
      For reg in na365 loop
        LP_INS_REG_LIQUIDEZ(p_fec_actual,
                            'CREDITOS VIGENTES SECTOR NO FINANCIERO',
                            V_MONEDA,
                            reg.nro_cuenta,
                            reg.mto_dev,
                            reg.saldo,
                            365,
                            reg.mto_prevision);
        V_MEN_1_ANO := nvl(V_MEN_1_ANO, 0) +
                       (nvl(reg.saldo, 0) + nvl(reg.mto_dev, 0) -
                        nvl(reg.mto_prevision, 0));
      End loop;
      For reg in na1095 loop
        LP_INS_REG_LIQUIDEZ(p_fec_actual,
                            'CREDITOS VIGENTES SECTOR NO FINANCIERO',
                            V_MONEDA,
                            reg.nro_cuenta,
                            reg.mto_dev,
                            reg.saldo,
                            1095,
                            reg.mto_prevision);
        V_MEN_3_ANOS := nvl(V_MEN_3_ANOS, 0) +
                        (nvl(reg.saldo, 0) + nvl(reg.mto_dev, 0) -
                         nvl(reg.mto_prevision, 0));
      End loop;
      For reg in nm1095 loop
        LP_INS_REG_LIQUIDEZ(p_fec_actual,
                            'CREDITOS VIGENTES SECTOR NO FINANCIERO',
                            V_MONEDA,
                            reg.nro_cuenta,
                            reg.mto_dev,
                            reg.saldo,
                            1096,
                            reg.mto_prevision);
        V_MAY_3_ANOS := nvl(V_MAY_3_ANOS, 0) +
                        (nvl(reg.saldo, 0) + nvl(reg.mto_dev, 0) -
                         nvl(reg.mto_prevision, 0));
      End loop;
      insert into sb_liquidez
        (FECHA,
         COD_MONEDA,
         CUENTA,
         DESCRIPCION,
         PLZ_VISTA,
         MEN_30_DIAS,
         MEN_90_DIAS,
         MEN_180_DIAS,
         MEN_1_ANO,
         MEN_3_ANOS,
         MAY_3_ANOS)
      values
        (p_fec_actual,
         V_MONEDA,
         14000000000000,
         'CREDITOS VIGENTES SECTOR NO FINANCIERO',
         v_sal_actual,
         v_men_30_dias,
         v_men_90_dias,
         v_men_180_dias,
         v_men_1_ano,
         v_men_3_anos,
         v_may_3_anos);
    END;
    /* Calcula la liquidez préstamos por cuotas moneda local */
    PROCEDURE LP_LIQ_CUO_MONLOC_PR(P_FEC_ACTUAL IN DATE) IS

      V_SAL_ACTUAL2  NUMBER(18, 2);
      V_SAL_ACTUAL1  NUMBER(18, 2);
      V_SAL_ACTUAL   NUMBER(18, 2);
      V_MEN_30_DIAS  NUMBER(18, 2);
      V_MEN_90_DIAS  NUMBER(18, 2);
      V_MEN_180_DIAS NUMBER(18, 2);
      V_MEN_1_ANO    NUMBER(18, 2);
      V_MEN_3_ANOS   NUMBER(18, 2);
      V_MAY_3_ANOS   NUMBER(18, 2);
      V_CUENTA       VARCHAR2(15);
      V_MONEDA       AH_CTA_CERTIFICADOS.COD_MONEDA%TYPE;
      -- MONEDA LOCAL --
      --plazos vistas vencidos menor a hoy
      Cursor fin is
        select pr.nro_cuenta,
               sum(nvl(pr.sal_capital, 0)) saldo,
               sum(nvl(pr.dev_no_cobrado, 0)) mto_dev,
               sum(nvl(pr.mto_prevision, 0)) mto_prevision
          from sb_liq_cuotas    pr,
               ge_cta_clientes  ct,
               ge_clientes      cl,
               pr_cta_prestamos x
         where pr.fec_vencimiento <= p_fec_actual --ya vencidos
           and pr.cod_moneda = V_MONEDA
           and pr.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and ct.cod_persona = cl.cod_persona
           and cl.cod_sec_contable IN ('F', 'P', 'I') --- Financiero y Publico
           and x.nro_cuenta = ct.nro_cuenta
           and x.est_batch in ('C', 'A') --Vigente, y Vig. c/Atraso--
         group by pr.nro_cuenta;

      -- Menores a 30 días
      Cursor men30 is
        select pr.nro_cuenta,
               sum(nvl(pr.sal_capital, 0)) saldo,
               sum(nvl(pr.dev_no_cobrado, 0)) mto_dev,
               sum(nvl(pr.mto_prevision, 0)) mto_prevision
          from sb_liq_cuotas    pr,
               ge_cta_clientes  ct,
               ge_clientes      cl,
               pr_cta_prestamos x
         where pr.fec_vencimiento - p_fec_actual between 1 and 30 --q venzan a partir de mañana
           and pr.cod_moneda = V_MONEDA
           and pr.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and ct.cod_persona = cl.cod_persona
           and cl.cod_sec_contable IN ('F', 'P', 'I') --- Financiero y Publico
           and x.nro_cuenta = ct.nro_cuenta
           and x.est_batch in ('C', 'A') --Vigente, y Vig. c/Atraso--
         group by pr.nro_cuenta;

      -- De 31 a 90 días
      Cursor a90 is
        select pr.nro_cuenta,
               sum(nvl(pr.sal_capital, 0)) saldo,
               sum(nvl(pr.dev_no_cobrado, 0)) mto_dev,
               sum(nvl(pr.mto_prevision, 0)) mto_prevision
          from sb_liq_cuotas    pr,
               ge_cta_clientes  ct,
               ge_clientes      cl,
               pr_cta_prestamos x
         where pr.fec_vencimiento - p_fec_actual between 31 and 90
           and pr.cod_moneda = V_MONEDA
           and pr.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and ct.cod_persona = cl.cod_persona
           and cl.cod_sec_contable IN ('F', 'P', 'I') --- Financiero y Publico
           and x.nro_cuenta = ct.nro_cuenta
           and x.est_batch in ('C', 'A') --Vigente, y Vig. c/Atraso--
         group by pr.nro_cuenta;

      -- De 91 a 180 dias
      Cursor a180 is
        select pr.nro_cuenta,
               sum(nvl(pr.sal_capital, 0)) saldo,
               sum(nvl(pr.dev_no_cobrado, 0)) mto_dev,
               sum(nvl(pr.mto_prevision, 0)) mto_prevision
          from sb_liq_cuotas    pr,
               ge_cta_clientes  ct,
               ge_clientes      cl,
               pr_cta_prestamos x
         where pr.fec_vencimiento - p_fec_actual between 91 and 180
           and pr.cod_moneda = V_MONEDA
           and pr.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and ct.cod_persona = cl.cod_persona
           and cl.cod_sec_contable IN ('F', 'P', 'I') --- Financiero y Publico
           and x.nro_cuenta = ct.nro_cuenta
           and x.est_batch in ('C', 'A') --Vigente, y Vig. c/Atraso--
         group by pr.nro_cuenta;

      -- De 181 a 365 dias
      Cursor a365 is
        select pr.nro_cuenta,
               sum(nvl(pr.sal_capital, 0)) saldo,
               sum(nvl(pr.dev_no_cobrado, 0)) mto_dev,
               sum(nvl(pr.mto_prevision, 0)) mto_prevision
          from sb_liq_cuotas    pr,
               ge_cta_clientes  ct,
               ge_clientes      cl,
               pr_cta_prestamos x
         where pr.fec_vencimiento - p_fec_actual between 181 and 365
           and pr.cod_moneda = V_MONEDA
           and pr.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and ct.cod_persona = cl.cod_persona
           and cl.cod_sec_contable IN ('F', 'P', 'I') --- Financiero y Publico
           and x.nro_cuenta = ct.nro_cuenta
           and x.est_batch in ('C', 'A') --Vigente, y Vig. c/Atraso--
         group by pr.nro_cuenta;

      -- De 365 a 1095 dias(3 años)
      Cursor a1095 is
        select pr.nro_cuenta,
               sum(nvl(pr.sal_capital, 0)) saldo,
               sum(nvl(pr.dev_no_cobrado, 0)) mto_dev,
               sum(nvl(pr.mto_prevision, 0)) mto_prevision
          from sb_liq_cuotas    pr,
               ge_cta_clientes  ct,
               ge_clientes      cl,
               pr_cta_prestamos x
         where pr.fec_vencimiento - p_fec_actual between 366 and 1095
           and pr.cod_moneda = V_MONEDA
           and pr.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and ct.cod_persona = cl.cod_persona
           and cl.cod_sec_contable IN ('F', 'P', 'I') --- Financiero y Publico
           and x.nro_cuenta = ct.nro_cuenta
           and x.est_batch in ('C', 'A') --Vigente, y Vig. c/Atraso--
         group by pr.nro_cuenta;

      -- Mayor 1095 dias(3 años)
      Cursor m1095 is
        select pr.nro_cuenta,
               sum(nvl(pr.sal_capital, 0)) saldo,
               sum(nvl(pr.dev_no_cobrado, 0)) mto_dev,
               sum(nvl(pr.mto_prevision, 0)) mto_prevision
          from sb_liq_cuotas    pr,
               ge_cta_clientes  ct,
               ge_clientes      cl,
               pr_cta_prestamos x
         where pr.fec_vencimiento - p_fec_actual > 1095
           and pr.cod_moneda = V_MONEDA
           and pr.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and ct.cod_persona = cl.cod_persona
           and cl.cod_sec_contable IN ('F', 'P', 'I') --- Financiero y Publico
           and x.nro_cuenta = ct.nro_cuenta
           and x.est_batch in ('C', 'A') --Vigente, y Vig. c/Atraso--
         group by pr.nro_cuenta;

      --sector no financiero
      Cursor nfin is
        select pr.nro_cuenta,
               sum(nvl(pr.sal_capital, 0)) saldo,
               sum(nvl(pr.dev_no_cobrado, 0)) mto_dev,
               sum(nvl(pr.mto_prevision, 0)) mto_prevision
          from sb_liq_cuotas    pr,
               ge_cta_clientes  ct,
               ge_clientes      cl,
               pr_cta_prestamos x
         where pr.fec_vencimiento <= p_fec_actual --ya vencidos
           and pr.cod_moneda = V_MONEDA
           and pr.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and ct.cod_persona = cl.cod_persona
           and cl.cod_sec_contable = 'N'
           and x.nro_cuenta = ct.nro_cuenta
           and x.est_batch in ('C', 'A') --Vigente, y Vig. c/Atraso--
         group by pr.nro_cuenta;

      -- Menores a 30 días
      Cursor nmen30 is
        select pr.nro_cuenta,
               sum(nvl(pr.sal_capital, 0)) saldo,
               sum(nvl(pr.dev_no_cobrado, 0)) mto_dev,
               sum(nvl(pr.mto_prevision, 0)) mto_prevision
          from sb_liq_cuotas    pr,
               ge_cta_clientes  ct,
               ge_clientes      cl,
               pr_cta_prestamos x
         where pr.fec_vencimiento - p_fec_actual between 1 and 30 --q venzan a partir de mañana
           and pr.cod_moneda = V_MONEDA
           and pr.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and ct.cod_persona = cl.cod_persona
           and cl.cod_sec_contable = 'N'
           and x.nro_cuenta = ct.nro_cuenta
           and x.est_batch in ('C', 'A') --Vigente, y Vig. c/Atraso--
         group by pr.nro_cuenta;

      -- De 31 a 90 días
      Cursor na90 is
        select pr.nro_cuenta,
               sum(nvl(pr.sal_capital, 0)) saldo,
               sum(nvl(pr.dev_no_cobrado, 0)) mto_dev,
               sum(nvl(pr.mto_prevision, 0)) mto_prevision
          from sb_liq_cuotas    pr,
               ge_cta_clientes  ct,
               ge_clientes      cl,
               pr_cta_prestamos x
         where pr.fec_vencimiento - p_fec_actual between 31 and 90
           and pr.cod_moneda = V_MONEDA
           and pr.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and ct.cod_persona = cl.cod_persona
           and cl.cod_sec_contable = 'N'
           and x.nro_cuenta = ct.nro_cuenta
           and x.est_batch in ('C', 'A') --Vigente, y Vig. c/Atraso--
         group by pr.nro_cuenta;

      -- De 91 a 180 dias
      Cursor na180 is
        select pr.nro_cuenta,
               sum(nvl(pr.sal_capital, 0)) saldo,
               sum(nvl(pr.dev_no_cobrado, 0)) mto_dev,
               sum(nvl(pr.mto_prevision, 0)) mto_prevision
          from sb_liq_cuotas    pr,
               ge_cta_clientes  ct,
               ge_clientes      cl,
               pr_cta_prestamos x
         where pr.fec_vencimiento - p_fec_actual between 91 and 180
           and pr.cod_moneda = V_MONEDA
           and pr.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and ct.cod_persona = cl.cod_persona
           and cl.cod_sec_contable = 'N'
           and x.nro_cuenta = ct.nro_cuenta
           and x.est_batch in ('C', 'A') --Vigente, y Vig. c/Atraso--
         group by pr.nro_cuenta;

      -- De 181 a 365 dias
      Cursor na365 is
        select pr.nro_cuenta,
               sum(nvl(pr.sal_capital, 0)) saldo,
               sum(nvl(pr.dev_no_cobrado, 0)) mto_dev,
               sum(nvl(pr.mto_prevision, 0)) mto_prevision
          from sb_liq_cuotas    pr,
               ge_cta_clientes  ct,
               ge_clientes      cl,
               pr_cta_prestamos x
         where pr.fec_vencimiento - p_fec_actual between 181 and 365
           and pr.cod_moneda = V_MONEDA
           and pr.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and ct.cod_persona = cl.cod_persona
           and cl.cod_sec_contable = 'N'
           and x.nro_cuenta = ct.nro_cuenta
           and x.est_batch in ('C', 'A') --Vigente, y Vig. c/Atraso--
         group by pr.nro_cuenta;

      -- De 365 a 1095 dias(3 años)
      Cursor na1095 is
        select pr.nro_cuenta,
               sum(nvl(pr.sal_capital, 0)) saldo,
               sum(nvl(pr.dev_no_cobrado, 0)) mto_dev,
               sum(nvl(pr.mto_prevision, 0)) mto_prevision
          from sb_liq_cuotas    pr,
               ge_cta_clientes  ct,
               ge_clientes      cl,
               pr_cta_prestamos x
         where pr.fec_vencimiento - p_fec_actual between 366 and 1095
           and pr.cod_moneda = V_MONEDA
           and pr.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and ct.cod_persona = cl.cod_persona
           and cl.cod_sec_contable = 'N'
           and x.nro_cuenta = ct.nro_cuenta
           and x.est_batch in ('C', 'A') --Vigente, y Vig. c/Atraso--
         group by pr.nro_cuenta;

      -- Mayor 1095 dias(3 años)
      Cursor nm1095 is
        select pr.nro_cuenta,
               sum(nvl(pr.sal_capital, 0)) saldo,
               sum(nvl(pr.dev_no_cobrado, 0)) mto_dev,
               sum(nvl(pr.mto_prevision, 0)) mto_prevision
          from sb_liq_cuotas    pr,
               ge_cta_clientes  ct,
               ge_clientes      cl,
               pr_cta_prestamos x
         where pr.fec_vencimiento - p_fec_actual > 1095
           and pr.cod_moneda = V_MONEDA
           and pr.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and ct.cod_persona = cl.cod_persona
           and cl.cod_sec_contable = 'N'
           and x.nro_cuenta = ct.nro_cuenta
           and x.est_batch in ('C', 'A') --Vigente, y Vig. c/Atraso--
         group by pr.nro_cuenta;
    BEGIN
      V_MONEDA := pag_gen.fu_obt_mon_local;
      -- Sector Financiero --
      V_SAL_ACTUAL   := 0;
      V_MEN_30_DIAS  := 0;
      V_MEN_90_DIAS  := 0;
      V_MEN_180_DIAS := 0;
      V_MEN_1_ANO    := 0;
      V_MEN_3_ANOS   := 0;
      V_MAY_3_ANOS   := 0;
      For reg in fin loop
        LP_INS_REG_LIQUIDEZ(p_fec_actual,
                            'CREDITOS VIGENTES SECTOR FINANCIERO',
                            V_MONEDA,
                            reg.nro_cuenta,
                            reg.mto_dev,
                            reg.saldo,
                            1,
                            reg.mto_prevision);
        V_SAL_ACTUAL := nvl(V_SAL_ACTUAL, 0) +
                        (nvl(reg.saldo, 0) + nvl(reg.mto_dev, 0) -
                         nvl(reg.mto_prevision, 0));
      End loop;
      For reg in men30 loop
        LP_INS_REG_LIQUIDEZ(p_fec_actual,
                            'CREDITOS VIGENTES SECTOR FINANCIERO',
                            V_MONEDA,
                            reg.nro_cuenta,
                            reg.mto_dev,
                            reg.saldo,
                            30,
                            reg.mto_prevision);
        V_MEN_30_DIAS := nvl(V_MEN_30_DIAS, 0) +
                         (nvl(reg.saldo, 0) + nvl(reg.mto_dev, 0) -
                          nvl(reg.mto_prevision, 0));
      End loop;
      For reg in a90 loop
        LP_INS_REG_LIQUIDEZ(p_fec_actual,
                            'CREDITOS VIGENTES SECTOR FINANCIERO',
                            V_MONEDA,
                            reg.nro_cuenta,
                            reg.mto_dev,
                            reg.saldo,
                            90,
                            reg.mto_prevision);
        V_MEN_90_DIAS := nvl(V_MEN_90_DIAS, 0) +
                         (nvl(reg.saldo, 0) + nvl(reg.mto_dev, 0) -
                          nvl(reg.mto_prevision, 0));
      End loop;
      For reg in a180 loop
        LP_INS_REG_LIQUIDEZ(p_fec_actual,
                            'CREDITOS VIGENTES SECTOR FINANCIERO',
                            V_MONEDA,
                            reg.nro_cuenta,
                            reg.mto_dev,
                            reg.saldo,
                            180,
                            reg.mto_prevision);
        V_MEN_180_DIAS := nvl(V_MEN_180_DIAS, 0) +
                          (nvl(reg.saldo, 0) + nvl(reg.mto_dev, 0) -
                           nvl(reg.mto_prevision, 0));
      End loop;
      For reg in a365 loop
        LP_INS_REG_LIQUIDEZ(p_fec_actual,
                            'CREDITOS VIGENTES SECTOR FINANCIERO',
                            V_MONEDA,
                            reg.nro_cuenta,
                            reg.mto_dev,
                            reg.saldo,
                            365,
                            reg.mto_prevision);
        V_MEN_1_ANO := nvl(V_MEN_1_ANO, 0) +
                       (nvl(reg.saldo, 0) + nvl(reg.mto_dev, 0) -
                        nvl(reg.mto_prevision, 0));
      End loop;
      For reg in a1095 loop
        LP_INS_REG_LIQUIDEZ(p_fec_actual,
                            'CREDITOS VIGENTES SECTOR FINANCIERO',
                            V_MONEDA,
                            reg.nro_cuenta,
                            reg.mto_dev,
                            reg.saldo,
                            1095,
                            reg.mto_prevision);
        V_MEN_3_ANOS := nvl(V_MEN_3_ANOS, 0) +
                        (nvl(reg.saldo, 0) + nvl(reg.mto_dev, 0) -
                         nvl(reg.mto_prevision, 0));
      End loop;
      For reg in m1095 loop
        LP_INS_REG_LIQUIDEZ(p_fec_actual,
                            'CREDITOS VIGENTES SECTOR FINANCIERO',
                            V_MONEDA,
                            reg.nro_cuenta,
                            reg.mto_dev,
                            reg.saldo,
                            1096,
                            reg.mto_prevision);
        V_MAY_3_ANOS := nvl(V_MAY_3_ANOS, 0) +
                        (nvl(reg.saldo, 0) + nvl(reg.mto_dev, 0) -
                         nvl(reg.mto_prevision, 0));
      End loop;
      insert into sb_liquidez
        (FECHA,
         COD_MONEDA,
         CUENTA,
         DESCRIPCION,
         PLZ_VISTA,
         MEN_30_DIAS,
         MEN_90_DIAS,
         MEN_180_DIAS,
         MEN_1_ANO,
         MEN_3_ANOS,
         MAY_3_ANOS)
      values
        (p_fec_actual,
         V_MONEDA,
         13000000000000,
         'CREDITOS VIGENTES SECTOR FINANCIERO',
         v_sal_actual,
         v_men_30_dias,
         v_men_90_dias,
         v_men_180_dias,
         v_men_1_ano,
         v_men_3_anos,
         v_may_3_anos);

      -- Sector No Financiero --
      V_SAL_ACTUAL   := 0;
      V_MEN_30_DIAS  := 0;
      V_MEN_90_DIAS  := 0;
      V_MEN_180_DIAS := 0;
      V_MEN_1_ANO    := 0;
      V_MEN_3_ANOS   := 0;
      V_MAY_3_ANOS   := 0;
      For reg in nfin loop
        LP_INS_REG_LIQUIDEZ(p_fec_actual,
                            'CREDITOS VIGENTES SECTOR NO FINANCIERO',
                            V_MONEDA,
                            reg.nro_cuenta,
                            reg.mto_dev,
                            reg.saldo,
                            1,
                            reg.mto_prevision);
        V_SAL_ACTUAL := nvl(V_SAL_ACTUAL, 0) +
                        (nvl(reg.saldo, 0) + nvl(reg.mto_dev, 0) -
                         nvl(reg.mto_prevision, 0));
      End loop;
      For reg in nmen30 loop
        LP_INS_REG_LIQUIDEZ(p_fec_actual,
                            'CREDITOS VIGENTES SECTOR NO FINANCIERO',
                            V_MONEDA,
                            reg.nro_cuenta,
                            reg.mto_dev,
                            reg.saldo,
                            30,
                            reg.mto_prevision);
        V_MEN_30_DIAS := nvl(V_MEN_30_DIAS, 0) +
                         (nvl(reg.saldo, 0) + nvl(reg.mto_dev, 0) -
                          nvl(reg.mto_prevision, 0));
      End loop;
      For reg in na90 loop
        LP_INS_REG_LIQUIDEZ(p_fec_actual,
                            'CREDITOS VIGENTES SECTOR NO FINANCIERO',
                            V_MONEDA,
                            reg.nro_cuenta,
                            reg.mto_dev,
                            reg.saldo,
                            90,
                            reg.mto_prevision);
        V_MEN_90_DIAS := nvl(V_MEN_90_DIAS, 0) +
                         (nvl(reg.saldo, 0) + nvl(reg.mto_dev, 0) -
                          nvl(reg.mto_prevision, 0));
      End loop;
      For reg in na180 loop
        LP_INS_REG_LIQUIDEZ(p_fec_actual,
                            'CREDITOS VIGENTES SECTOR NO FINANCIERO',
                            V_MONEDA,
                            reg.nro_cuenta,
                            reg.mto_dev,
                            reg.saldo,
                            180,
                            reg.mto_prevision);
        V_MEN_180_DIAS := nvl(V_MEN_180_DIAS, 0) +
                          (nvl(reg.saldo, 0) + nvl(reg.mto_dev, 0) -
                           nvl(reg.mto_prevision, 0));
      End loop;
      For reg in na365 loop
        LP_INS_REG_LIQUIDEZ(p_fec_actual,
                            'CREDITOS VIGENTES SECTOR NO FINANCIERO',
                            V_MONEDA,
                            reg.nro_cuenta,
                            reg.mto_dev,
                            reg.saldo,
                            365,
                            reg.mto_prevision);
        V_MEN_1_ANO := nvl(V_MEN_1_ANO, 0) +
                       (nvl(reg.saldo, 0) + nvl(reg.mto_dev, 0) -
                        nvl(reg.mto_prevision, 0));
      End loop;
      For reg in na1095 loop
        LP_INS_REG_LIQUIDEZ(p_fec_actual,
                            'CREDITOS VIGENTES SECTOR NO FINANCIERO',
                            V_MONEDA,
                            reg.nro_cuenta,
                            reg.mto_dev,
                            reg.saldo,
                            1095,
                            reg.mto_prevision);
        V_MEN_3_ANOS := nvl(V_MEN_3_ANOS, 0) +
                        (nvl(reg.saldo, 0) + nvl(reg.mto_dev, 0) -
                         nvl(reg.mto_prevision, 0));
      End loop;
      For reg in nm1095 loop
        LP_INS_REG_LIQUIDEZ(p_fec_actual,
                            'CREDITOS VIGENTES SECTOR NO FINANCIERO',
                            V_MONEDA,
                            reg.nro_cuenta,
                            reg.mto_dev,
                            reg.saldo,
                            1096,
                            reg.mto_prevision);
        V_MAY_3_ANOS := nvl(V_MAY_3_ANOS, 0) +
                        (nvl(reg.saldo, 0) + nvl(reg.mto_dev, 0) -
                         nvl(reg.mto_prevision, 0));
      End loop;
      insert into sb_liquidez
        (FECHA,
         COD_MONEDA,
         CUENTA,
         DESCRIPCION,
         PLZ_VISTA,
         MEN_30_DIAS,
         MEN_90_DIAS,
         MEN_180_DIAS,
         MEN_1_ANO,
         MEN_3_ANOS,
         MAY_3_ANOS)
      values
        (p_fec_actual,
         V_MONEDA,
         14000000000000,
         'CREDITOS VIGENTES SECTOR NO FINANCIERO',
         v_sal_actual,
         v_men_30_dias,
         v_men_90_dias,
         v_men_180_dias,
         v_men_1_ano,
         v_men_3_anos,
         v_may_3_anos);
    END;
    PROCEDURE LP_CAL_LIQ_TARJETAS(P_FEC_ACTUAL IN DATE) IS

      V_SAL_ACTUAL2  NUMBER(18, 2);
      V_SAL_ACTUAL1  NUMBER(18, 2);
      V_SAL_ACTUAL   NUMBER(18, 2);
      V_MEN_30_DIAS  NUMBER(18, 2);
      V_MEN_90_DIAS  NUMBER(18, 2);
      V_MEN_180_DIAS NUMBER(18, 2);
      V_MEN_1_ANO    NUMBER(18, 2);
      V_MEN_3_ANOS   NUMBER(18, 2);
      V_MAY_3_ANOS   NUMBER(18, 2);
      V_CUENTA       VARCHAR2(15);
      V_MONEDA       AH_CTA_CERTIFICADOS.COD_MONEDA%TYPE;
      V_PLAZO        NUMBER;
      V_SALDO        NUMBER;
      V_DESCRIPCION  VARCHAR2(200);
      Cursor c_tarjetas is
        select t.nro_cuenta,
               t.cod_moneda,
               case
                 when nvl(t.cat_automatica, 1) = 1 then
                 --when nvl(t.dia_mora,0) <= 60 then
                  case
                    when cl.cod_sec_contable = 'F' then
                     '13000000000000'
                    when cl.cod_sec_contable = 'P' then
                     '14000000000000'
                    when cl.cod_sec_contable = 'I' then
                     '14000000000000'
                    when cl.cod_sec_contable = 'N' then
                     '14000000000000'
                  end
               end rubro,
               round(sum(((nvl(b.saldo, 0) - nvl(v.monto, 0)) * 5) / 100) * 1,
                     0) DE_00,
               round(sum(((nvl(b.saldo, 0) - nvl(v.monto, 0)) * 5) / 100) * 2,
                     0) DE_1_a_30,
               round(sum(((nvl(b.saldo, 0) - nvl(v.monto, 0)) * 5) / 100) * 3,
                     0) DE_31_a_90,
               round(sum(((nvl(b.saldo, 0) - nvl(v.monto, 0)) * 5) / 100) * 4,
                     0) DE_91_a_180,
               round(sum(((nvl(b.saldo, 0) - nvl(v.monto, 0)) * 5) / 100) * 5,
                     0) DE_181_a_365,
               sum((nvl(b.saldo, 0) - nvl(v.monto, 0))) -
               round((round(sum(((nvl(b.saldo, 0) - nvl(v.monto, 0)) * 5) / 100) * 1,
                            0) +
                     round(sum(((nvl(b.saldo, 0) - nvl(v.monto, 0)) * 5) / 100) * 2,
                            0) +
                     round(sum(((nvl(b.saldo, 0) - nvl(v.monto, 0)) * 5) / 100) * 3,
                            0) +
                     round(sum(((nvl(b.saldo, 0) - nvl(v.monto, 0)) * 5) / 100) * 4,
                            0) +
                     round(sum(((nvl(b.saldo, 0) - nvl(v.monto, 0)) * 5) / 100) * 5,
                            0)),
                     0) DE_366_a_1095,
               0 DE_1096_A_MAS,
               sum(((nvl(b.saldo, 0) - nvl(v.monto, 0)))) total,
               sum((nvl(b.saldo, 0))) saldo_capital,
               sum((nvl(v.monto, 0))) mto_prevision,
               0 interes_devengado,
               count(distinct b.nro_cuenta) cantidad
          from ta_cta_tarjetas t,
               ge_cta_clientes ct,
               ge_clientes cl,
               (select t.nro_cuenta,
                       (nvl(t.sal_facturar, 0) + nvl(t.sal_facturado, 0) +
                       nvl(t.sal_financiado, 0) +
                       nvl(t.sal_cuo_pendientes, 0)) saldo
                  from ta_cta_tarjetas t
                 where t.estado <> 'C'
                   and nvl(t.cat_automatica, 1) = 1

                ) b,
               (select p.nro_cuenta, nvl(p.monto, 0) monto
                  from ta_previsiones p
                 where p.fecha =
                       (select max(p1.fecha)
                          from ta_previsiones p1
                         where p1.nro_cuenta = p.nro_cuenta)) v
         where t.nro_cuenta = b.nro_cuenta
           and t.nro_cuenta = v.nro_cuenta(+)
           and t.estado <> 'C'
           and nvl(t.cat_automatica, 1) = 1
              --and nvl(t.dia_mora,0) <= 60 --- Solo los vigentes
           and t.nro_cuenta = ct.nro_cuenta
           and ct.relacion = 'P'
           and cl.cod_persona = ct.cod_persona
         group by t.nro_cuenta,
                  t.cod_moneda,
                  case
                    when nvl(t.cat_automatica, 1) = 1 then
                    --when nvl(t.dia_mora,0) <= 60 then
                     case
                       when cl.cod_sec_contable = 'F' then
                        '13000000000000'
                       when cl.cod_sec_contable = 'P' then
                        '14000000000000'
                       when cl.cod_sec_contable = 'I' then
                        '14000000000000'
                       when cl.cod_sec_contable = 'N' then
                        '14000000000000'
                     end
                  end;
    BEGIN
      For reg in c_tarjetas loop
        V_SAL_ACTUAL   := 0;
        V_MEN_30_DIAS  := 0;
        V_MEN_90_DIAS  := 0;
        V_MEN_180_DIAS := 0;
        V_MEN_1_ANO    := 0;
        V_MEN_3_ANOS   := 0;
        V_MAY_3_ANOS   := 0;
        V_PLAZO        := 0;
        V_SALDO        := 0;
        --LP_INS_REG_LIQUIDEZ(p_fec_actual, 'CREDITOS VIGENTES SECTOR NO FINANCIERO',
        --                    reg.cod_moneda, reg.nro_cuenta, 0, reg.saldo_capital, 0, reg.mto_prevision);
        if reg.rubro like '14%' then
          v_descripcion := 'CREDITOS VIGENTES SECTOR NO FINANCIERO';
        else
          v_descripcion := 'CREDITOS VIGENTES SECTOR FINANCIERO';
        end if;

        if reg.de_00 <> 0 then
          v_plazo      := 1;
          v_sal_actual := reg.de_00;
          v_saldo      := reg.de_00;
          LP_INS_REG_LIQUIDEZ(p_fec_actual,
                              v_descripcion,
                              reg.cod_moneda,
                              reg.nro_cuenta,
                              0,
                              v_saldo,
                              v_plazo,
                              0);
        end if;
        if reg.de_1_a_30 <> 0 then
          v_plazo       := 30;
          v_men_30_dias := reg.de_1_a_30;
          v_saldo       := reg.de_1_a_30;
          LP_INS_REG_LIQUIDEZ(p_fec_actual,
                              v_descripcion,
                              reg.cod_moneda,
                              reg.nro_cuenta,
                              0,
                              v_saldo,
                              v_plazo,
                              0);
        end if;
        if reg.de_31_a_90 <> 0 then
          v_plazo       := 90;
          V_MEN_90_DIAS := reg.de_31_a_90;
          v_saldo       := reg.de_31_a_90;
          LP_INS_REG_LIQUIDEZ(p_fec_actual,
                              v_descripcion,
                              reg.cod_moneda,
                              reg.nro_cuenta,
                              0,
                              v_saldo,
                              v_plazo,
                              0);
        end if;
        if reg.de_91_a_180 <> 0 then
          v_plazo        := 180;
          V_MEN_180_DIAS := reg.de_91_a_180;
          v_saldo        := reg.de_91_a_180;
          LP_INS_REG_LIQUIDEZ(p_fec_actual,
                              v_descripcion,
                              reg.cod_moneda,
                              reg.nro_cuenta,
                              0,
                              v_saldo,
                              v_plazo,
                              0);
        end if;
        if reg.de_181_a_365 <> 0 then
          v_plazo     := 365;
          v_men_1_ano := reg.de_181_a_365;
          v_saldo     := reg.de_181_a_365;
          LP_INS_REG_LIQUIDEZ(p_fec_actual,
                              v_descripcion,
                              reg.cod_moneda,
                              reg.nro_cuenta,
                              0,
                              v_saldo,
                              v_plazo,
                              0);
        end if;
        if reg.de_366_a_1095 <> 0 then
          v_plazo      := 1095;
          v_men_3_anos := reg.de_366_a_1095;
          v_saldo      := reg.de_366_a_1095;
          LP_INS_REG_LIQUIDEZ(p_fec_actual,
                              v_descripcion,
                              reg.cod_moneda,
                              reg.nro_cuenta,
                              0,
                              v_saldo,
                              v_plazo,
                              0);
        end if;
        if reg.de_1096_a_mas <> 0 then
          v_plazo      := 1096;
          v_may_3_anos := reg.de_1096_a_mas;
          v_saldo      := reg.de_1096_a_mas;
          LP_INS_REG_LIQUIDEZ(p_fec_actual,
                              v_descripcion,
                              reg.cod_moneda,
                              reg.nro_cuenta,
                              0,
                              v_saldo,
                              v_plazo,
                              0);
        end if;
        update sb_liquidez
           set PLZ_VISTA    = nvl(plz_vista, 0) + v_sal_actual,
               MEN_30_DIAS  = nvl(men_30_dias, 0) + v_men_30_dias,
               MEN_90_DIAS  = nvl(MEN_90_DIAS, 0) + v_men_90_dias,
               MEN_180_DIAS = nvl(MEN_180_DIAS, 0) + v_men_180_dias,
               MEN_1_ANO    = nvl(MEN_1_ANO, 0) + v_men_1_ano,
               MEN_3_ANOS   = nvl(MEN_3_ANOS, 0) + v_men_3_anos,
               MAY_3_ANOS   = nvl(MAY_3_ANOS, 0) + v_may_3_anos
         where FECHA = p_fec_actual
           and COD_MONEDA = reg.cod_moneda
           and CUENTA = reg.rubro;
      End loop;
    END;
  BEGIN
    p_fec_actual := pag_cal.fu_obt_fec_actual(3);
    DELETE FROM SB_LIQUIDEZ WHERE FECHA = P_FEC_ACTUAL;
    DELETE FROM SB_LIQUIDEZ_DET WHERE FECHA = P_FEC_ACTUAL;

    lp_cal_liq_mon_local(P_FEC_ACTUAL);
    lp_cal_liq_mon_extr(P_FEC_ACTUAL);
    --LP_INS_REG_LIQUIDEZ(P_FEC_ACTUAL,P_DESCRIPCION,P_MONEDA,P_NROCTA,
    --                    P_MTODEV,P_MTOCAP,P_PLAZO);
    --LP_INS_REG_LIQUIDEZ(p_fec_actual, P_DESCRIPCION, P_MONEDA, P_NROCTA, P_MTODEV, P_MTOCAP, P_PLAZO);
    --prestamos
    if fug_obt_tip_implementacion <> 3 then
      lp_cal_liq_monloc_pr(P_FEC_ACTUAL);
      lp_cal_liq_monext_pr(P_FEC_ACTUAL);
    else
      prs_gen_ana_liq_cuo(P_FEC_ACTUAL);
      lp_liq_cuo_monloc_pr(P_FEC_ACTUAL);
      lp_liq_cuo_monext_pr(P_FEC_ACTUAL);
      LP_CAL_LIQ_TARJETAS(P_FEC_ACTUAL);
    end if;
    --LP_INS_REG_LIQUIDEZ(P_FEC_ACTUAL,P_DESCRIPCION,P_MONEDA,P_NROCTA,
    --                    P_MTODEV,P_MTOCAP,P_PLAZO);
    --LP_INS_REG_LIQUIDEZ(p_fec_actual, P_DESCRIPCION, P_MONEDA, P_NROCTA, P_MTODEV, P_MTOCAP, P_PLAZO);

  END;
  /* Genera los depositoos en casa matriz y dependencias. */
  PROCEDURE PR_GEN_DEP_OFICINAS IS

    /* Contar cantidad de clientes por oficina */
    FUNCTION LF_CAN_CLI_ACT_OFI(P_COD_OFICINA IN NUMBER,
                                P_TIP_MONEDA  IN VARCHAR2) RETURN NUMBER;
    /* Insertar registro de depositos por oficina */
    PROCEDURE LP_INS_SB_DEP_OFICIN(RP_SDOFI IN SB_DEP_OFICINAS%ROWTYPE);
    v_fec_actual     ge_calendarios.fec_actual%type;
    v_cod_mon_local  ba_monedas.cod_moneda%type;
    v_cod_mon_fuerte ba_monedas.cod_moneda%type;
    v_cod_ofi_ant    ba_oficinas.cod_oficina%type;
    v_tip_mon_ant    varchar2(02);
    r_sdofi          sb_dep_oficinas%rowtype;
    r_sdofi_det      sb_dep_oficinas_det%rowtype;
    --- Cursor de saldos de cartera por oficina y moneda
    cursor c_dep_oficinas is --- Cda y cupones vencidos en vista
      select decode(ah.cod_moneda, v_cod_mon_local, 'ML', 'ME') tip_moneda,
             ah.cod_oficina,
             31 cod_modalidad,
             nvl(sum(decode(ah.est_cer_batch,
                            'V',
                            ah.sal_tot_batch,
                            'P',
                            ah.sal_tot_batch,
                            ah.sal_tot_batch - ah.capital) *
                     decode(ah.cod_moneda,
                            v_cod_mon_local,
                            1,
                            pag_gen.fu_obt_cotizacion(ah.cod_moneda,
                                                      v_fec_actual))),
                 0) saldo
        from ah_cta_certificados ah
       where ah.est_batch NOT IN ('T', 'A', 'C', 'X')
         and (est_cer_batch IN ('V', 'P') or sal_tot_batch > capital)
            --agregado para excluir retenidos--
         and nvl(ah.sal_ret_batch, 0) = 0
       group by decode(ah.cod_moneda, v_cod_mon_local, 'ML', 'ME'),
                ah.cod_oficina,
                31
      UNION ALL
      select decode(ah.cod_moneda, v_cod_mon_local, 'ML', 'ME') tip_moneda,
             ah.cod_oficina,
             ah.cod_modalidad,
             nvl(sum((nvl(sal_tot_batch, 0) -
                     decode(fug_obt_tip_implementacion,
                             2,
                             nvl(sal_ret_batch, 0),
                             0)) *
                     decode(ah.cod_moneda,
                            v_cod_mon_local,
                            1,
                            pag_gen.fu_obt_cotizacion(ah.cod_moneda,
                                                      v_fec_actual))),
                 0)
        from ah_cta_vistas ah
       where est_batch not in ('A', 'C') --Abierta y cancelada
       group by decode(ah.cod_moneda, v_cod_mon_local, 'ML', 'ME'),
                ah.cod_oficina,
                ah.cod_modalidad
      UNION ALL --- Cda sector no financiero
      select decode(ah.cod_moneda, v_cod_mon_local, 'ML', 'ME') tip_moneda,
             ah.cod_oficina,
             ah.cod_modalidad,
             nvl(sum((capital) *
                     decode(ah.cod_moneda,
                            v_cod_mon_local,
                            1,
                            pag_gen.fu_obt_cotizacion(ah.cod_moneda,
                                                      v_fec_actual))),
                 0)
        from ah_cta_certificados ah, ge_cta_clientes cc, ge_clientes cl
       where ah.est_cer_batch not in ('V', 'P')
         and ah.est_batch NOT IN ('T', 'A', 'C', 'X')
         and ah.sal_tot_batch > 0
         and cc.nro_cuenta = ah.nro_cuenta
         and cc.cod_persona = cl.cod_persona
         and cc.relacion = 'P'
         and cl.cod_sec_contable <> 'F'
            --agregado para excluir retenidos--
         and nvl(ah.sal_ret_batch, 0) = 0
       group by decode(ah.cod_moneda, v_cod_mon_local, 'ML', 'ME'),
                ah.cod_oficina,
                ah.cod_modalidad
      UNION ALL --- Cda sector financiero
      select decode(ah.cod_moneda, v_cod_mon_local, 'ML', 'ME') tip_moneda,
             ah.cod_oficina,
             32,
             nvl(sum((capital) *
                     decode(ah.cod_moneda,
                            v_cod_mon_local,
                            1,
                            pag_gen.fu_obt_cotizacion(ah.cod_moneda,
                                                      v_fec_actual))),
                 0)
        from ah_cta_certificados ah, ge_cta_clientes cc, ge_clientes cl
       where ah.est_cer_batch not in ('V', 'P')
         and ah.est_batch NOT IN ('T', 'A', 'C', 'X')
         and ah.sal_tot_batch > 0
         and cc.nro_cuenta = ah.nro_cuenta
         and cc.relacion = 'P'
         and cc.cod_persona = cl.cod_persona
         and cl.cod_sec_contable = 'F'
            --agregado para excluir retenidos--
         and nvl(ah.sal_ret_batch, 0) = 0
       group by decode(ah.cod_moneda, v_cod_mon_local, 'ML', 'ME'),
                ah.cod_oficina,
                ah.cod_modalidad
       order by 1, 2, 3;

    /* Contar cantidad de clientes por oficina */
    FUNCTION LF_CAN_CLI_ACT_OFI(P_COD_OFICINA IN NUMBER,
                                P_TIP_MONEDA  IN VARCHAR2) RETURN NUMBER IS
      v_cantidad number(07);
    BEGIN
      select nvl(count(*), 0)
        into v_cantidad
        from ge_clientes cl
       where cl.cod_oficina = p_cod_oficina
         and exists
       (select 1
                from ge_cta_clientes cc, ge_cuentas cu
               where cc.cod_persona = cl.cod_persona
                 and cc.nro_cuenta = cu.nro_cuenta
                 and p_tip_moneda = decode(cu.cod_moneda,
                                           pag_gen.FU_OBT_MON_LOCAL,
                                           'ML',
                                           'ME')
                 and cu.estado not in ('T', 'C', 'A')
                 and cu.cod_modalidad in
                     (31, 32, 33, 34, 35, 36, 41, 42, 334));
      return v_cantidad;
    END;
    /* Insertar registro de depositos por oficina */
    PROCEDURE LP_INS_SB_DEP_OFICIN(RP_SDOFI IN SB_DEP_OFICINAS%ROWTYPE) IS
      Cursor Oficinas is
        select ah.nro_cuenta,
               decode(ah.cod_moneda, v_cod_mon_local, 'ML', 'ME') tip_moneda,
               ah.cod_oficina,
               31 cod_modalidad,
               nvl((decode(ah.est_cer_batch,
                           'V',
                           ah.sal_tot_batch,
                           'P',
                           ah.sal_tot_batch,
                           ah.sal_tot_batch - ah.capital) *
                   decode(ah.cod_moneda,
                           v_cod_mon_local,
                           1,
                           pag_gen.fu_obt_cotizacion(ah.cod_moneda,
                                                     v_fec_actual))),
                   0) saldo
          from ah_cta_certificados ah
         where ah.est_batch NOT IN ('T', 'A', 'C', 'X')
           and (est_cer_batch IN ('V', 'P') or sal_tot_batch > capital)
              --agregado para excluir retenidos--
           and nvl(ah.sal_ret_batch, 0) = 0
        UNION ALL
        select ah.nro_cuenta,
               decode(ah.cod_moneda, v_cod_mon_local, 'ML', 'ME') tip_moneda,
               ah.cod_oficina,
               ah.cod_modalidad,
               nvl(((nvl(sal_tot_batch, 0) -
                   decode(fug_obt_tip_implementacion,
                            2,
                            nvl(sal_ret_batch, 0),
                            0)) *
                   decode(ah.cod_moneda,
                           v_cod_mon_local,
                           1,
                           pag_gen.fu_obt_cotizacion(ah.cod_moneda,
                                                     v_fec_actual))),
                   0)
          from ah_cta_vistas ah
         where est_batch not in ('A', 'C') --Abierta y cancelada
        UNION ALL --- Cda sector no financiero
        select ah.nro_cuenta,
               decode(ah.cod_moneda, v_cod_mon_local, 'ML', 'ME') tip_moneda,
               ah.cod_oficina,
               ah.cod_modalidad,
               nvl(((capital) *
                   decode(ah.cod_moneda,
                           v_cod_mon_local,
                           1,
                           pag_gen.fu_obt_cotizacion(ah.cod_moneda,
                                                     v_fec_actual))),
                   0)
          from ah_cta_certificados ah, ge_cta_clientes cc, ge_clientes cl
         where ah.est_cer_batch not in ('V', 'P')
           and ah.est_batch NOT IN ('T', 'A', 'C', 'X')
           and ah.sal_tot_batch > 0
           and cc.nro_cuenta = ah.nro_cuenta
           and cc.cod_persona = cl.cod_persona
           and cc.relacion = 'P'
           and cl.cod_sec_contable <> 'F'
              --agregado para excluir retenidos--
           and nvl(ah.sal_ret_batch, 0) = 0
        UNION ALL --- Cda sector financiero
        select ah.nro_cuenta,
               decode(ah.cod_moneda, v_cod_mon_local, 'ML', 'ME') tip_moneda,
               ah.cod_oficina,
               32,
               nvl(((capital) *
                   decode(ah.cod_moneda,
                           v_cod_mon_local,
                           1,
                           pag_gen.fu_obt_cotizacion(ah.cod_moneda,
                                                     v_fec_actual))),
                   0)
          from ah_cta_certificados ah, ge_cta_clientes cc, ge_clientes cl
         where ah.est_cer_batch not in ('V', 'P')
           and ah.est_batch NOT IN ('T', 'A', 'C', 'X')
           and ah.sal_tot_batch > 0
           and cc.nro_cuenta = ah.nro_cuenta
           and cc.relacion = 'P'
           and cc.cod_persona = cl.cod_persona
           and cl.cod_sec_contable = 'F'
              --agregado para excluir retenidos--
           and nvl(ah.sal_ret_batch, 0) = 0
         order by 2, 1, 3;
      v_control    varchar2(1) := 'N';
      v_cotizacion sb_dep_oficinas.val_cotizacion%type;
      v_cant_sup   number(10);
      v_cant_otr   number(10);
      v_cant_cli   number(10);
    BEGIN
      For reg in oficinas loop
        -- Inserta el detalle
        If reg.tip_moneda = 'ME' and v_control = 'N' then
          v_cotizacion := pag_gen.fu_obt_cotizacion(v_cod_mon_fuerte,
                                                    v_fec_actual);
          v_control    := 'S';
        End if;
        insert into sb_dep_oficinas_det
          (fecha,
           cod_moneda,
           cod_oficina,
           nro_cuenta,
           val_cotizacion,
           saldo)
        values
          (v_fec_actual,
           reg.tip_moneda,
           reg.cod_oficina,
           reg.nro_cuenta,
           v_cotizacion,
           reg.saldo);
      End loop;
      --* busca cantidad de empleados superiores y otros
      if fug_obt_tip_implementacion = 2 then
        begin
          select sum(decode(r.val_maximo, 1, 1, 0)),
                 sum(decode(r.val_maximo, 2, 1, 0))
            into v_cant_sup, v_cant_otr
            from ba_usuarios u, ba_cod_referencias r
           where u.categoria is not null
             and u.categoria = r.val_minimo
             and u.cod_oficina = rp_sdofi.cod_oficina
             and u.estado = 'A'
             and exists
           (select 1
                    from ge_cta_clientes cc, ge_cuentas cu
                   where cc.cod_persona = u.cod_persona
                     and cc.nro_cuenta = cu.nro_cuenta
                     and rp_sdofi.cod_moneda = cu.cod_moneda
                     and cu.estado not in ('T', 'C', 'A')
                     and cu.cod_modalidad in (31, 32, 33, 41, 42, 334));
        exception
          when others then
            v_cant_sup := 0;
            v_cant_otr := 0;
        end;
        --* resta del total de clientes los empleados, porq van en otra columna
        if rp_sdofi.CAN_CTA_CLIENTES > 0 then
          v_cant_cli := nvl(rp_sdofi.CAN_CTA_CLIENTES, 0) -
                        nvl(v_cant_otr, 0) - nvl(v_Cant_sup, 0);
        else
          v_cant_cli := nvl(rp_sdofi.CAN_CTA_CLIENTES, 0);
          v_cant_otr := 0;
          v_cant_sup := 0;
        end if;
      else
        v_cant_cli := nvl(rp_sdofi.CAN_CTA_CLIENTES, 0);
        v_cant_otr := nvl(rp_sdofi.CAN_CTA_PER_OTR, 0);
        v_cant_sup := nvl(rp_sdofi.CAN_CTA_PER_SUP, 0);
      end if;
      --*
      insert into sb_dep_oficinas -- Inserta el resumen
        (FECHA,
         COD_MONEDA,
         COD_OFICINA,
         VAL_COTIZACION,
         CAN_CTA_PER_SUP,
         CAN_CTA_PER_OTR,
         CAN_CTA_CLIENTES,
         MTO_CTA_CORRIENTES,
         MTO_CTA_VISTAS,
         MTO_CTA_PLAZOS,
         MTO_CTA_CERTIFICADOS,
         MTO_CTA_TITULOS)
      values
        (rp_sdofi.FECHA,
         rp_sdofi.COD_MONEDA,
         rp_sdofi.COD_OFICINA,
         rp_sdofi.VAL_COTIZACION,
         nvl(v_Cant_sup, 0),
         nvl(v_cant_otr, 0),
         nvl(v_cant_cli, 0),
         nvl(rp_sdofi.MTO_CTA_CORRIENTES, 0),
         nvl(rp_sdofi.MTO_CTA_VISTAS, 0),
         nvl(rp_sdofi.MTO_CTA_PLAZOS, 0),
         nvl(rp_sdofi.MTO_CTA_CERTIFICADOS, 0),
         nvl(rp_sdofi.MTO_CTA_TITULOS, 0));
    END;
  BEGIN
    v_fec_actual := pag_cal.fu_obt_fec_actual(3);
    DELETE FROM SB_DEP_OFICINAS WHERE FECHA = V_FEC_ACTUAL;
    DELETE FROM SB_DEP_OFICINAS_DET WHERE FECHA = V_FEC_ACTUAL;

    v_cod_mon_local  := pag_gen.fu_obt_mon_local;
    v_cod_mon_fuerte := pas_bcp.fu_obt_mon_fuerte;
    v_cod_ofi_ant    := -1;
    v_tip_mon_ant    := 'x';
    --- Variables para todos los registros
    r_sdofi.fecha          := v_fec_actual;
    r_sdofi.val_cotizacion := pag_gen.fu_obt_cotizacion(v_cod_mon_fuerte,
                                                        v_fec_actual);
    for ofi in c_dep_oficinas loop
      if v_cod_ofi_ant = -1 then
        v_cod_ofi_ant := ofi.cod_oficina;
        v_tip_mon_ant := ofi.tip_moneda;
      end if;
      if v_cod_ofi_ant <> ofi.cod_oficina or
         v_tip_mon_ant <> ofi.tip_moneda then
        -- CORTE
        if v_tip_mon_ant = 'ME' then
          r_sdofi.cod_moneda := v_cod_mon_fuerte;
        else
          r_sdofi.cod_moneda     := v_cod_mon_local;
          r_sdofi.val_cotizacion := null;
        end if;
        r_sdofi.cod_oficina := v_cod_ofi_ant;
        --- Contar cantidad de clientes vigentes por oficina
        r_sdofi.can_cta_clientes := lf_can_cli_act_ofi(v_cod_ofi_ant,
                                                       v_tip_mon_ant);
        --- Insertar registro en tabla de informe
        r_sdofi.MTO_CTA_CORRIENTES   := round(r_sdofi.MTO_CTA_CORRIENTES / 1000,
                                              0);
        r_sdofi.MTO_CTA_VISTAS       := round(r_sdofi.MTO_CTA_VISTAS / 1000,
                                              0);
        r_sdofi.MTO_CTA_PLAZOS       := round(r_sdofi.MTO_CTA_PLAZOS / 1000,
                                              0);
        r_sdofi.MTO_CTA_CERTIFICADOS := round(r_sdofi.MTO_CTA_CERTIFICADOS / 1000,
                                              0);
        r_sdofi.MTO_CTA_TITULOS      := round(r_sdofi.MTO_CTA_TITULOS / 1000,
                                              0);
        lp_ins_sb_dep_oficin(r_sdofi);
        --- Inicializar totales
        v_cod_ofi_ant                := ofi.cod_oficina;
        v_tip_mon_ant                := ofi.tip_moneda;
        r_sdofi.cod_oficina          := ofi.cod_oficina;
        r_sdofi.CAN_CTA_PER_SUP      := 0;
        r_sdofi.CAN_CTA_PER_OTR      := 0;
        r_sdofi.CAN_CTA_CLIENTES     := 0;
        r_sdofi.MTO_CTA_CORRIENTES   := 0;
        r_sdofi.MTO_CTA_VISTAS       := 0;
        r_sdofi.MTO_CTA_PLAZOS       := 0;
        r_sdofi.MTO_CTA_CERTIFICADOS := 0;
        r_sdofi.MTO_CTA_TITULOS      := 0;
      end if;
      if ofi.cod_modalidad IN (31, 334) then
        r_sdofi.mto_cta_vistas := (nvl(r_sdofi.mto_cta_vistas, 0) +
                                  nvl(ofi.saldo, 0));
      elsif ofi.cod_modalidad = 32 then
        r_sdofi.mto_cta_plazos := round((nvl(r_sdofi.mto_cta_plazos, 0) +
                                        nvl(ofi.saldo, 0)),
                                        0);
      elsif ofi.cod_modalidad = 33 then
        r_sdofi.mto_cta_certificados := round((nvl(r_sdofi.mto_cta_certificados,
                                                   0) + nvl(ofi.saldo, 0)),
                                              0);
      elsif ofi.cod_modalidad in (34, 35) then
        r_sdofi.mto_cta_titulos := round((nvl(r_sdofi.mto_cta_titulos, 0) +
                                         nvl(ofi.saldo, 0)),
                                         0);
      elsif ofi.cod_modalidad in (41, 42) then
        r_sdofi.mto_cta_corrientes := round((nvl(r_sdofi.mto_cta_corrientes,
                                                 0) + nvl(ofi.saldo, 0)),
                                            0);
      end if;
    end loop;
    -- Ultimo registro
    --- Contar cantidad de clientes vigentes por oficina
    r_sdofi.can_cta_clientes     := lf_can_cli_act_ofi(v_cod_ofi_ant,
                                                       v_tip_mon_ant);
    r_sdofi.MTO_CTA_CORRIENTES   := round(r_sdofi.MTO_CTA_CORRIENTES / 1000,
                                          0);
    r_sdofi.MTO_CTA_VISTAS       := round(r_sdofi.MTO_CTA_VISTAS / 1000, 0);
    r_sdofi.MTO_CTA_PLAZOS       := round(r_sdofi.MTO_CTA_PLAZOS / 1000, 0);
    r_sdofi.MTO_CTA_CERTIFICADOS := round(r_sdofi.MTO_CTA_CERTIFICADOS / 1000,
                                          0);
    r_sdofi.MTO_CTA_TITULOS      := round(r_sdofi.MTO_CTA_TITULOS / 1000, 0);
    lp_ins_sb_dep_oficin(r_sdofi);
  END;
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
  PROCEDURE PR_GEN_APE_TAS_SEM IS

    V_FEC_ACTUAL         DATE;
    V_MONTO              SB_TAS_APE_SEMANALES.MONTO%TYPE;
    V_TASA_NOMINAL       SB_TAS_APE_SEMANALES.VAL_TAS_NOMINAL%TYPE;
    V_NRO_SOLICITUD      PR_CTA_PRESTAMOS.NRO_SOLICITUD%TYPE;
    V_DIAS               NUMBER(6);
    V_CAPITAL            AH_CTA_CERTIFICADOS.CAPITAL%TYPE;
    V_NRO_CUENTA         SB_TAS_APE_SEMANALES.NRO_CUENTA%TYPE;
    V_TIP_CAPITALIZACION AH_CTA_CERTIFICADOS.TIP_CAPITALIZACION%TYPE;
    V_TASA_EFECTIVA      SB_TAS_APE_SEMANALES.VAL_TAS_EFECTIVA%TYPE;
    V_MON_ORIG           SB_TAS_APE_SEMANALES.MTO_APE_ORIGINAL%TYPE;
    V_COD_MON_ORIG       SB_TAS_APE_SEMANALES.COD_MON_ORIGINAL%TYPE;
    V_PLAZO              GE_PLZ_CONTABLES.COD_PLAZO%TYPE;
    v_cod_mon_local      ba_monedas.cod_moneda%type;

    v_periodo           number(10);
    v_val_tasa          ge_tas_fechas.val_tasa%type;
    v_can_dia_acumulado cc_sal_mensuales.can_dia_acumulado%type;
    v_sal_acumulado     cc_sal_mensuales.sal_acu_deudor%type;
    v_sal_promedio      cc_sal_mensuales.sal_acu_deudor%type;
    v_sal_orig          number(18, 2);
    v_semana            mi_sb_tas_ape_semanales.corcod%type;
    v_redondeo          number(2) := 0;
    r_mcdoc             md_cta_documentos%rowtype;
    --- Recuperar datos de cuentas - diario
    cursor c_cuentas is
      select a.cod_modulo,
             a.cod_modalidad,
             a.cod_oficina,
             a.cod_moneda,
             a.nro_cuenta,
             sal_contable,
             nvl(p.fec_ini_rrr, a.fec_apertura) fec_apertura,
             a.fec_vencimiento,
             a.val_tasa,
             tas_personalizada,
             cod_tasa
        from ge_cuentas a, ge_est_cuentas b, pr_cta_prestamos p
       where a.cod_modulo = b.cod_modulo
         and a.cod_modalidad = b.cod_modalidad
         and a.estado = b.estado
         and activo = 'S'
         and (a.cod_modulo = 6 or (a.cod_modulo = 3 and a.estado <> 'A') or
             a.cod_modalidad in (37, 38) or
             (a.cod_modulo = 10 and
             (fug_obt_pardinamico('MDD_MAD_EMI_CALLMONEY',
                                    a.cod_modulo,
                                    a.cod_modalidad,
                                    null,
                                    null,
                                    null) = 'S' or
             fug_obt_pardinamico('MDD_MAD_REC_CALLMONEY',
                                    a.cod_modulo,
                                    a.cod_modalidad,
                                    null,
                                    null,
                                    null) = 'S')))
         and nvl(sal_contable, 0) > 0
         and ((nvl(a.val_tasa, 0) > 0 and a.cod_modulo = 6) or
             (nvl(a.val_tasa, 0) = 0 and a.cod_modalidad = 33) or
             (nvl(a.val_tasa, 0) > 0 and a.cod_modalidad in (37, 38)) or
             (a.cod_modulo = 10 and
             (fug_obt_pardinamico('MDD_MAD_EMI_CALLMONEY',
                                    a.cod_modulo,
                                    a.cod_modalidad,
                                    null,
                                    null,
                                    null) = 'S' or
             fug_obt_pardinamico('MDD_MAD_REC_CALLMONEY',
                                    a.cod_modulo,
                                    a.cod_modalidad,
                                    null,
                                    null,
                                    null) = 'S')))
         and a.nro_cuenta = p.nro_cuenta(+)  
         and ((nvl(p.fec_ini_rrr, a.fec_apertura) = v_fec_actual) or
             (trunc(a.fec_insercion) = v_fec_actual and
             a.cod_modalidad = 675));

    cursor c_certificados is
      select nvl(sal_tot_batch, 0) - nvl(sal_ret_batch, 0)
        from ah_cta_certificados
       where nro_cuenta = v_nro_cuenta;

    cursor c_cert is
      select tip_capitalizacion, capital
        from ah_cta_certificados
       where nro_cuenta = v_nro_cuenta;

    cursor c_prestamos is
      select nro_solicitud, mto_capital
        from pr_cta_prestamos
       where nro_cuenta = v_nro_cuenta;
    cursor c_pla_fijo is
      select nvl(sal_tot_batch, 0) - nvl(sal_ret_batch, 0)
        from ah_cta_plazos
       where nro_cuenta = v_nro_cuenta ;
    cursor c_plazo_fijo is
      select tip_capitalizacion, capital
        from ah_cta_plazos
       where nro_cuenta = v_nro_cuenta;

    --- Recuperar datos de cuentas--- esto es mensual --agregado x VC
    cursor c_cuentas_men is
      select a.cod_modulo,
             a.cod_modalidad,
             cod_oficina,
             cod_moneda,
             nro_cuenta,
             sal_contable,
             fec_apertura,
             fec_vencimiento,
             val_tasa,
             tas_personalizada,
             cod_tasa
        from ge_cuentas a, ge_est_cuentas b
       where a.cod_modulo = b.cod_modulo
         and a.cod_modalidad = b.cod_modalidad
         and a.estado = b.estado
         and activo = 'S' --sólo las activas
         and (a.cod_modalidad IN (31, 334) and a.cod_modulo = 3 and
             a.estado <> 'A')
      union
      select a.cod_modulo,
             a.cod_modalidad,
             cod_oficina,
             cod_moneda,
             nro_cuenta,
             sal_contable,
             fec_apertura,
             fec_vencimiento,
             val_tasa,
             tas_personalizada,
             cod_tasa
        from ge_cuentas a, ge_est_cuentas b
       where a.cod_modulo = b.cod_modulo
         and a.cod_modalidad = b.cod_modalidad
         and a.estado = b.estado
         and activo = 'N' --sólo las activas
         and a.cod_modalidad IN (31, 334)
         and a.cod_modulo = 3
         and a.estado <> 'A'
         and nvl(a.sal_contable, 0) != 0
      union
      select a.cod_modulo,
             a.cod_modalidad,
             cod_oficina,
             cod_moneda,
             nro_cuenta,
             abs(sal_contable),
             fec_apertura,
             fec_vencimiento,
             val_tasa,
             tas_personalizada,
             cod_tasa
        from ge_cuentas a, ge_est_cuentas b
       where a.cod_modulo = b.cod_modulo
         and a.cod_modalidad = b.cod_modalidad
         and a.estado = b.estado
         and activo = 'S' --sólo las activas
         and a.cod_modalidad != 55
         and (a.cod_modulo = 5 and nvl(a.val_tasa, 0) > 0 and
             a.estado <> 'A')
      union
      select a.cod_modulo,
             a.cod_modalidad,
             cod_oficina,
             cod_moneda,
             nro_cuenta,
             abs(sal_contable),
             fec_apertura,
             fec_vencimiento,
             val_tasa,
             tas_personalizada,
             cod_tasa
        from ge_cuentas a, ge_est_cuentas b
       where a.cod_modulo = b.cod_modulo
         and a.cod_modalidad = b.cod_modalidad
         and a.estado = b.estado
         and a.cod_moneda <> 'EUR' --OJO MIENTRAS...
         and activo = 'S' --sólo las activas
         and a.cod_modalidad = 41
       order by 1, 4;

    --sobregiros cb_sal_inventarios_his
    cursor c_sobregiros is
      select nvl(sum(d.sal_actual), 0) monto
        from cb_sal_inventarios_det_his d,
             cb_sal_inventarios_his     c,
             ba_monedas                 m
       where c.fecha = v_fec_actual
         and d.nro_referencia = c.nro_referencia
         and d.fecha = c.fecha
         and c.cod_moneda = m.cod_moneda
         and c.cod_modulo = 4
         and c.cod_modalidad = 41
         and nvl(c.sal_total, 0) != 0
         and (substr(c.cod_rubro, 6, 3) in ('187', '189') or
             substr(c.cod_rubro, 6, 5) in ('21508', '39702'))
         and c.cod_rubro is not null
         and d.nro_cuenta = v_nro_cuenta;

    --Saldo Ahorro a la Vista Mensual.
    cursor c_vistas is
      select nvl(sum(d.sal_actual), 0) monto
        from cb_sal_inventarios_det_his d,
             cb_sal_inventarios_his     c,
             ba_monedas                 m
       where c.fecha = v_fec_actual
         and d.nro_referencia = c.nro_referencia
         and d.fecha = c.fecha
         and c.cod_moneda = m.cod_moneda
         and c.cod_modulo = 3
         and c.cod_modalidad IN (31, 334)
         and nvl(c.sal_total, 0) != 0
         and substr(c.cod_rubro, 6, 3) IN
             ('102', '196', '138', '236', '238', '292')
         and substr(c.cod_rubro, 6, 5) not IN ('13804', '13805') -- OMM 30/11/2015
         and c.cod_rubro is not null
         and d.nro_cuenta = v_nro_cuenta;

    cursor c_cta_vistas is
      select tip_capitalizacion
        from ah_cta_vistas
       where nro_cuenta = v_nro_cuenta;

    --Saldos de Tarjetas Mensuales.
    cursor c_tarjetas is
      select nvl(sum(d.sal_actual), 0) monto
        from cb_sal_inventarios_det_his d,
             cb_sal_inventarios_his     c,
             ba_monedas                 m
       where c.fecha = v_fec_actual
         and d.nro_referencia = c.nro_referencia
         and d.fecha = c.fecha
         and c.cod_moneda = m.cod_moneda
         and c.cod_modulo = 5
         and c.cod_modalidad != 55
         and nvl(c.sal_total, 0) != 0
         and substr(c.cod_rubro, 6, 3) IN ('205', '265', '275', '269')
         and c.cod_rubro is not null
         and d.nro_cuenta = v_nro_cuenta;

  begin

    PAG_CAL.PR_OBT_DAT_CALENDAR(4);
    v_fec_actual    := pag_cal.fu_obt_fec_actual(4);
    v_cod_mon_local := PAG_GEN.FU_OBT_MON_LOCAL;
    v_redondeo      := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                                           null,
                                           null,
                                           v_cod_mon_local);
    --Verificacion de semana
    begin
      select semana
        into v_semana
        from sb_semanas
       where v_fec_actual between desde and hasta;
    exception
      when no_data_found then
        raise_application_error(-20000,
                                'No existe Semana definida para la fecha a procesar');
    end;
    --sólo si es el último día hábil del mes, se generan los informes mensuales (VC)
    -- Se comenta debido al ticket CIE-281
    /*if v_fec_actual = PAG_CAL.G_ULT_DIA_MES_HABIL then
      for cuo in c_cuentas_men loop

        v_nro_cuenta := cuo.nro_cuenta;
        If cuo.cod_modulo = 3 then
          open c_vistas;
          fetch c_vistas
            into v_monto;
          close c_vistas;
          open c_cta_vistas;
          fetch c_cta_vistas
            into v_tip_capitalizacion;
          close c_cta_vistas;
        elsif cuo.cod_modulo = 4 then
          open c_sobregiros;
          fetch c_sobregiros
            into v_monto;
          close c_sobregiros;
        elsif cuo.cod_modulo = 5 then
          open c_tarjetas;
          fetch c_tarjetas
            into v_monto;
          close c_tarjetas;
        End if;
        v_cod_mon_orig := cuo.cod_moneda;
        v_mon_orig     := v_monto;
        v_sal_orig     := v_monto;

        v_dias := nvl(cuo.fec_vencimiento, cuo.fec_apertura + 1) -
                  cuo.fec_apertura;
        If cuo.cod_modalidad in (31, 41, 334) then
          v_plazo := 1;
        else
          v_plazo := FUG_OBT_PLZ_CONTABLE(v_dias);
        end if;
        ---
        v_tasa_nominal := null;
        If cuo.val_tasa is null and cuo.cod_tasa is not null then
          v_tasa_nominal := FUG_OBT_VAL_TASA(cuo.cod_modulo,
                                             cuo.cod_modalidad,
                                             cuo.cod_oficina,
                                             cuo.nro_cuenta,
                                             cuo.cod_moneda,
                                             v_mon_orig,
                                             cuo.tas_personalizada,
                                             cuo.cod_tasa,
                                             null,
                                             v_fec_actual);
        else
          If cuo.cod_modulo = 4 then
            v_tasa_nominal := 0;
          Else
            v_tasa_nominal := cuo.val_tasa;
          End if;
        End if;
        --
        if cuo.cod_modalidad IN (31, 334) then
          select decode(v_tip_capitalizacion,
                        1,
                        30,
                        2,
                        60,
                        3,
                        90,
                        4,
                        120,
                        6,
                        180,
                        12,
                        365,
                        99,
                        v_plazo,
                        null)
            into v_periodo
            from dual;
          v_tasa_efectiva := round(pas_bcp.fu_obt_tae(v_tasa_nominal,
                                                      v_periodo),
                                   2);
        elsif cuo.cod_modulo = 4 then
          --obtiene saldo promedio
          pag_cta.pr_obt_sal_promedio(cuo.cod_modulo,
                                      cuo.cod_modalidad,
                                      cuo.cod_oficina,
                                      cuo.nro_cuenta,
                                      v_fec_actual,
                                      v_fec_actual,
                                      v_sal_acumulado,
                                      v_sal_promedio,
                                      v_can_dia_acumulado);
          v_val_tasa      := fug_obt_val_tasa(cuo.cod_modulo,
                                              cuo.cod_modalidad,
                                              cuo.cod_oficina,
                                              cuo.nro_cuenta,
                                              cuo.cod_moneda,
                                              v_SAL_PROMEDIO,
                                              cuo.tas_personalizada,
                                              null,
                                              550,
                                              v_fec_actual); --busca x la transacciòn de sobregiro
          v_tasa_efectiva := pas_bcp.FU_OBT_TAE(v_val_tasa, 30);
          v_tasa_nominal  := v_val_tasa;
        elsif cuo.cod_modulo = 5 then
          --TAE de tarjetas no se calcula porque viene de la procesadora 20061206 JCLG
          v_tasa_efectiva := round(pas_bcp.fu_obt_tae(v_tasa_nominal, 30),
                                   2);
        end if;
        if v_monto != 0 then
          --Inserto en la tabla.
          insert into sb_tas_ape_semanales
            (nro_cuenta,
             cod_modulo,
             cod_modalidad,
             cod_mon_original,
             cod_moneda,
             fec_apertura,
             mto_ape_original, --saldo fin de mes
             monto,
             val_tas_nominal,
             val_tas_efectiva,
             sal_pro_acu_origen,
             sal_pro_acumulado,
             cod_plazo,
             usu_insercion,
             fec_insercion,
             usu_modificacion,
             fec_modificacion)
          values
            (cuo.nro_cuenta,
             cuo.cod_modulo,
             cuo.cod_modalidad,
             v_cod_mon_orig,
             v_cod_mon_local,
             v_fec_actual,
             v_sal_orig,
             v_monto,
             v_tasa_nominal,
             v_tasa_efectiva,
             v_mon_orig,
             v_monto,
             v_plazo,
             user,
             sysdate,
             user,
             sysdate);
        end if;

      end loop;
    end if;*/

    for cuo in c_cuentas loop
      BEGIN
        v_nro_cuenta := cuo.nro_cuenta;
        if cuo.cod_modulo = 10 then
          pam_doc.pr_obt_datos(cuo.nro_cuenta, r_mcdoc);
          v_cod_mon_orig := cuo.cod_moneda;
          v_monto        := cuo.sal_contable;
          v_mon_orig     := r_mcdoc.monto;
          v_tasa_nominal := r_mcdoc.val_tasa;
          if (r_mcdoc.fec_vencimiento - r_mcdoc.fec_inicio) = 0 then
            v_dias := 1;
          else
            v_dias := r_mcdoc.fec_vencimiento - r_mcdoc.fec_inicio;
          end if;
          v_plazo         := FUG_OBT_PLZ_CONTABLE(v_dias);
          v_tasa_efectiva := pas_bcp.fu_obt_tae(v_tasa_nominal, v_dias);
        else
          If cuo.cod_modulo = 3 and cuo.cod_modalidad = 33 then
            open c_certificados;
            fetch c_certificados
              into v_monto;
            close c_certificados;
          elsif cuo.cod_modulo = 3 and cuo.cod_modalidad in (37, 38) then
            open c_pla_fijo;
            fetch c_pla_fijo
              into v_monto;
            close c_pla_fijo;
          else
            v_monto := cuo.sal_contable;
          End if;
          v_cod_mon_orig := cuo.cod_moneda;
          v_mon_orig     := v_monto;
          v_dias         := nvl(cuo.fec_vencimiento, cuo.fec_apertura + 1) -
                            cuo.fec_apertura;
          v_plazo        := FUG_OBT_PLZ_CONTABLE(v_dias);
          If cuo.val_tasa is null then
            v_tasa_nominal := FUG_OBT_VAL_TASA(cuo.cod_modulo,
                                               cuo.cod_modalidad,
                                               cuo.cod_oficina,
                                               cuo.nro_cuenta,
                                               cuo.cod_moneda,
                                               v_mon_orig,
                                               cuo.tas_personalizada,
                                               cuo.cod_tasa,
                                               null,
                                               v_fec_actual);
          else
            v_tasa_nominal := cuo.val_tasa;
          End if;
          if cuo.cod_modulo = 3 and cuo.cod_modalidad in (37, 38) then
            open c_plazo_fijo;
            fetch c_plazo_fijo
              into v_tip_capitalizacion, v_capital;
            close c_plazo_fijo;
            v_tasa_efectiva := PAS_BCP.FU_OBT_TAE_CDA(v_tip_capitalizacion,
                                                      v_tasa_nominal,
                                                      v_dias,
                                                      v_capital);
          elsif cuo.cod_modulo = 3 then
            open c_cert;
            fetch c_cert
              into v_tip_capitalizacion, v_capital;
            close c_cert;
            v_tasa_efectiva := PAS_BCP.FU_OBT_TAE_CDA(v_tip_capitalizacion,
                                                      v_tasa_nominal,
                                                      v_dias,
                                                      v_capital);
          elsif cuo.cod_modulo = 6 then
            open c_prestamos;
            fetch c_prestamos
              into v_nro_solicitud, v_monto;
            close c_prestamos;
            v_mon_orig := v_monto;
            If v_nro_solicitud is not null then
              PAS_BCP.PR_OBT_TAS_PRESTAMO(v_nro_solicitud,
                                          null,
                                          v_tasa_efectiva,
                                          v_tasa_nominal);
            Else
              PAS_BCP.PR_OBT_TAS_PRESTAMO(null,
                                          cuo.nro_cuenta,
                                          v_tasa_efectiva,
                                          v_tasa_nominal);
            End if;
          End if;
        End if;
        --Inserto en la tabla.
        insert into sb_tas_ape_semanales
          (nro_cuenta,
           cod_modulo,
           cod_modalidad,
           cod_mon_original,
           cod_moneda,
           fec_apertura,
           mto_ape_original,
           monto,
           val_tas_nominal,
           val_tas_efectiva,
           cod_plazo,
           usu_insercion,
           fec_insercion,
           usu_modificacion,
           fec_modificacion)
        values
          (cuo.nro_cuenta,
           cuo.cod_modulo,
           cuo.cod_modalidad,
           v_cod_mon_orig,
           v_cod_mon_local,
           cuo.fec_apertura,
           v_mon_orig,
           v_monto,
           v_tasa_nominal,
           v_tasa_efectiva,
           v_plazo,
           user,
           sysdate,
           user,
           sysdate);
      EXCEPTION
        WHEN ZERO_DIVIDE THEN
          DBMS_OUTPUT.put_line('Zero divide error - Try again');
        WHEN OTHERS THEN
          raise_application_error(-20000,
                                  'Cur.II -Nro.CTa ' || v_nro_cuenta || '-' ||
                                  sqlerrm);

      END;

    End loop;

  end;
  /* Obtener devengado total de CDA. */
  FUNCTION FU_OBT_DEV_CDA(P_NRO_CUENTA   IN GE_CUENTAS.NRO_CUENTA%TYPE,
                          P_CAPITAL      IN AH_CTA_CERTIFICADOS.CAPITAL%TYPE,
                          P_FEC_APERTURA IN AH_CTA_CERTIFICADOS.FEC_APERTURA%TYPE,
                          P_FEC_CALCULO  IN DATE) RETURN NUMBER IS
    v_devengado       ah_devengados_his.mto_interes%type := 0;
    v_devengado2      ah_devengados_his.mto_interes%type := 0;
    v_fec_inicio      ah_devengados.fec_inicio%type;
    v_max_fec_inicio  ah_devengados.fec_inicio%type;
    v_fecha           ah_devengados.fecha%type;
    v_fec_vencimiento ah_cta_certificados.fec_vencimiento%type;
    v_est_batch       ah_cta_certificados.est_batch%type;

  BEGIN
    select SUM(nvl(d.mto_dev_acumulado, 0)) -- round(nvl(pag_gen.fu_cal_int_simple(p_capital, p_fec_calculo-p_fec_apertura, d.val_tasa),0),0)
      into v_devengado
      from ah_devengados d
     where d.nro_cuenta = p_nro_cuenta
       and d.fecha = p_fec_calculo
       and d.fec_inicio = (Select max(fec_inicio)
                             from ah_devengados dv
                            where dv.nro_cuenta = p_nro_cuenta
                              and dv.fecha = p_fec_calculo);

    select sum(nvl(a.mto_interes, 0))
      into v_devengado2
      from ah_cupones a
     where a.nro_cuenta = p_nro_cuenta
       and a.fec_vencimiento = p_fec_calculo
       and a.estado = 'E'
       and nvl(a.fec_pago, p_fec_calculo) >= p_fec_calculo;

    /*   Select max(fec_inicio)
         into v_max_fec_inicio
         from ah_devengados
        where nro_cuenta = p_nro_cuenta;
    begin
       select dev.mto_dev_acumulado, dev.fec_inicio, dev.fecha, cta.fec_vencimiento, cta.est_batch
         into v_devengado, v_fec_inicio, v_fecha, v_fec_vencimiento, v_est_batch
         from ah_devengados dev, ah_cta_certificados cta, ge_calendarios cal
        where cta.nro_cuenta = p_nro_cuenta
          and dev.nro_cuenta = p_nro_cuenta
          and cal.cod_modulo = 3
          --and dev.fecha = cal.fec_actual;
          and dev.fec_inicio = v_max_fec_inicio;
    exception
    when too_many_rows then
        RAISE_APPLICATION_ERROR (-20002,p_nro_cuenta);
    end;
       --******--
       If v_max_fec_inicio = v_fec_inicio and v_fec_vencimiento > v_fecha and v_est_batch != 'T' Then
          v_devengado:= nvl(v_devengado,0);
       Else
          v_devengado:= 0;
       End If;

       --******--
    */
    return nvl(v_devengado, 0) + nvl(v_devengado2, 0);
  END;
  /* Obtener devengado de Ahorro a la Vista. */
  FUNCTION FU_OBT_DEV_AV(P_NRO_CUENTA             IN GE_CUENTAS.NRO_CUENTA%TYPE,
                         P_FEC_ULT_CAPITALIZACION IN AH_CTA_VISTAS.FEC_ULT_CAPITALIZACION%TYPE)
    RETURN NUMBER IS
    v_devengado ah_devengados_his.mto_interes%type;
  BEGIN
    select nvl(sum(nvl(mto_dev_acumulado, 0)), 0)
      into v_devengado
      from ah_devengados
     where nro_cuenta = p_nro_cuenta
       and fecha = p_fec_ult_capitalizacion;
    return v_devengado;
  END;
  PROCEDURE PR_GEN_DEP_INS_CAPTA IS

    PROCEDURE LP_CAL_DEP_MON_EXTR;
    PROCEDURE LP_CAL_DEP_MON_LOCAL;

    PROCEDURE LP_CAL_DEP_MON_EXTR IS
      v_mto_vista1  ah_cta_vistas.sal_total%type := 0;
      v_mto_vista   ah_cta_vistas.sal_total%type := 0;
      v_mto_vistaex ah_cta_vistas.sal_total%type := 0;
      v_mto_vista2  ah_cta_vistas.sal_total%type := 0;
      v_can_vista   number(10) := 0;
      v_can_vistaex number(10) := 0;
      v_can_vista1  number(10) := 0;
      v_mto_TIF1    ah_cta_vistas.sal_total%type := 0;
      v_can_TIF1    number(10) := 0;
      v_mto_TIF1ex  ah_cta_vistas.sal_total%type := 0;
      v_can_TIF1ex  number(10) := 0;
      v_mto_TIF2    ah_cta_vistas.sal_total%type := 0;
      v_can_TIF2    number(10) := 0;
      v_mto_TIF2ex  ah_cta_vistas.sal_total%type := 0;
      v_can_TIF2ex  number(10) := 0;
      v_mto_CDA1    ah_cta_vistas.sal_total%type := 0;
      v_can_CDA1    number(10) := 0;
      v_mto_CDA1ex  ah_cta_vistas.sal_total%type := 0;
      v_can_CDA1ex  number(10) := 0;
      v_mto_CDA2    ah_cta_vistas.sal_total%type := 0;
      v_can_CDA2    number(10) := 0;
      v_mto_CDA2ex  ah_cta_vistas.sal_total%type := 0;
      v_can_CDA2ex  number(10) := 0;
      v_mto_CTA     ah_cta_vistas.sal_total%type := 0;
      v_mto_CTAS    ah_cta_vistas.sal_total%type := 0;
      v_can_CTA     number(10) := 0;
      v_can_CTAS    number(10) := 0;
      v_persona     varchar2(1) := 0;

      v_cotizacion number(10);
      --
      Cursor monedas is
        select distinct (cod_moneda) cod_moneda
          from ba_monedas
         where cod_moneda <> pag_gen.fu_obt_mon_local;
    begin
      FOR v_contador IN 1 .. 2 LOOP
        IF v_contador = 1 then
          v_persona := 'F';
        else
          v_persona := 'J';
        end if;
        v_mto_CDA1ex  := 0;
        v_can_CDA1ex  := 0;
        v_mto_CDA2ex  := 0;
        v_can_CDA2ex  := 0;
        v_mto_TIF1ex  := 0;
        v_can_TIF1ex  := 0;
        v_mto_TIF2ex  := 0;
        v_can_TIF2ex  := 0;
        v_can_vistaex := 0;
        v_mto_vistaex := 0;
        v_can_CTAS    := 0;
        v_mto_CTAS    := 0;
        FOR reg in monedas LOOP
          ---v_cotizacion := pag_gen.fu_obt_cotizacion(reg.cod_moneda, pag_cal.fu_obt_fec_actual(3)-1);
          v_cotizacion := pag_gen.fu_obt_cotizacion(reg.cod_moneda,
                                                    pag_cal.fu_obt_fec_actual(3));
          /* Depositantes por vista, moneda local - personas físicas */
          --
          select round(nvl(sum(decode(ah.est_cer_batch,
                                      'V',
                                      ah.sal_tot_batch,
                                      'P',
                                      ah.sal_tot_batch,
                                      ah.sal_tot_batch - ah.capital)) *
                           v_cotizacion / 1000,
                           0),
                       0),
                 count(distinct pe.cod_persona)
            into v_mto_vista1, v_can_vista1
            from ah_cta_certificados ah, ge_cta_clientes cl, ba_personas pe
           where est_batch NOT IN ('T', 'A', 'C', 'X')
             and (est_cer_batch in ('V', 'P') or sal_tot_batch > capital)
             and cod_moneda = reg.cod_moneda
             and cl.nro_cuenta = ah.nro_cuenta
             and pe.cod_persona = cl.cod_persona
             and pe.tipo = v_persona
             and cl.relacion = 'P';
          --
          select round(nvl(sum(NVL(sal_tot_batch, 0)) * v_cotizacion / 1000,
                           0),
                       0),
                 count(distinct pe.cod_persona)
            into v_mto_vista, v_can_vista
            from ah_cta_vistas ah, ge_cta_clientes cl, ba_personas pe
           where cod_moneda = reg.cod_moneda
             and est_batch not in ('A', 'C')
             and cl.nro_cuenta = ah.nro_cuenta
             and pe.cod_persona = cl.cod_persona
             and pe.tipo = v_persona
             and cl.relacion = 'P'; --Abierta y cancelada

          v_mto_vista := nvl(v_mto_vista, 0) + nvl(v_mto_vista1, 0);
          v_can_vista := v_can_vista + v_can_vista1;
          /* Depositantes por título */
          -- Plazo  <= 90 días
          select round(nvl(sum(capital) * v_cotizacion / 1000, 0), 0),
                 count(distinct pe.cod_persona)
            into v_mto_TIF1, v_can_TIF1
            from ah_cta_certificados ah,
                 ge_clientes         c,
                 ge_cta_clientes     cl,
                 ba_personas         pe
           where fec_vencimiento - fec_apertura <= 90
             and (c.cod_sec_contable = 'F' or ah.cod_modalidad = 34)
             and est_cer_batch not in ('V', 'P')
             and est_batch NOT IN ('T', 'A', 'C', 'X')
             and cod_moneda = reg.cod_moneda
             and cl.nro_cuenta = ah.nro_cuenta
             and pe.cod_persona = cl.cod_persona
             and c.cod_persona = cl.cod_persona
             and pe.tipo = v_persona
             and cl.relacion = 'P';
          -- Plazo  > 90 días
          select round(nvl(sum(capital) * v_cotizacion / 1000, 0), 0),
                 count(distinct pe.cod_persona)
            into v_mto_TIF2, v_can_TIF2
            from ah_cta_certificados ah,
                 ge_clientes         c,
                 ge_cta_clientes     cl,
                 ba_personas         pe
           where fec_vencimiento - fec_apertura > 90
             and (c.cod_sec_contable = 'F' or ah.cod_modalidad = 34)
             and est_cer_batch not in ('V', 'P')
             and est_batch NOT IN ('T', 'A', 'C', 'X')
             and cod_moneda = reg.cod_moneda
             and cl.nro_cuenta = ah.nro_cuenta
             and c.cod_persona = cl.cod_persona
             and pe.cod_persona = cl.cod_persona
             and pe.tipo = v_persona
             and cl.relacion = 'P';
          /* Calcula CDA */
          -- Plazo  Menor o igual a 360 días
          select round(nvl(sum(capital) * v_cotizacion / 1000, 0), 0),
                 count(distinct pe.cod_persona)
            into v_mto_CDA1, v_can_CDA1
            from ah_cta_certificados ah,
                 ge_clientes         c,
                 ge_cta_clientes     cl,
                 ba_personas         pe
           where fec_vencimiento - fec_apertura <= 360
             and est_cer_batch not in ('V', 'P')
             and ah.cod_modalidad = 33
             and c.cod_sec_contable <> 'F'
             and c.cod_persona = cl.cod_persona
             and est_batch NOT IN ('T', 'A', 'C', 'X')
             and cod_moneda = reg.cod_moneda
             and cl.nro_cuenta = ah.nro_cuenta
             and pe.cod_persona = cl.cod_persona
             and pe.tipo = v_persona
             and cl.relacion = 'P';
          -- Plazo  Mayor a 360 días
          select round(nvl(sum(capital) * v_cotizacion / 1000, 0), 0),
                 count(distinct pe.cod_persona)
            into v_mto_CDA2, v_can_CDA2
            from ah_cta_certificados ah,
                 ge_clientes         c,
                 ge_cta_clientes     cl,
                 ba_personas         pe
           where fec_vencimiento - fec_apertura > 360
             and est_cer_batch not in ('V', 'P')
             and ah.cod_modalidad = 33
             and c.cod_sec_contable <> 'F'
             and c.cod_persona = cl.cod_persona
             and est_batch NOT IN ('T', 'A', 'C', 'X')
             and cod_moneda = reg.cod_moneda
             and cl.nro_cuenta = ah.nro_cuenta
             and pe.cod_persona = cl.cod_persona
             and pe.tipo = v_persona
             and cl.relacion = 'P';
          /* Calcula CTA. CTE. */
          -- Monto
          select round(nvl(sum(sal_total) * v_cotizacion / 1000, 0), 0),
                 count(distinct pe.cod_persona)
            into v_mto_CTA, v_can_CTA
            from cc_cta_corrientes ah, ge_cta_clientes cl, ba_personas pe
           where ah.est_batch not in ('V', 'P')
             and ah.cod_modalidad = 41
             and est_batch NOT IN ('T', 'A', 'C', 'X')
             and cod_moneda = reg.cod_moneda
             and cl.nro_cuenta = ah.nro_cuenta
             and pe.cod_persona = cl.cod_persona
             and pe.tipo = v_persona
             and cl.relacion = 'P';
          v_can_CTAS := nvl(v_can_CTAS, 0) + v_can_CTA;
          v_mto_CTAS := nvl(v_mto_CTAS, 0) + v_mto_CTA;

          v_can_vistaex := nvl(v_can_vistaex, 0) + v_can_vista;
          v_mto_vistaex := nvl(v_mto_vistaex, 0) + v_mto_vista;
          v_can_TIF1ex  := nvl(v_can_TIF1ex, 0) + v_can_TIF1;
          v_mto_TIF1ex  := nvl(v_mto_TIF1ex, 0) + v_mto_TIF1;
          v_can_TIF2ex  := nvl(v_can_TIF2ex, 0) + v_can_TIF2;
          v_mto_TIF2ex  := nvl(v_mto_TIF2ex, 0) + v_mto_TIF2;
          v_can_CDA1ex  := nvl(v_can_CDA1ex, 0) + v_can_CDA1;
          v_mto_CDA1ex  := nvl(v_mto_CDA1ex, 0) + v_mto_CDA1;
          v_can_CDA2ex  := nvl(v_can_CDA2ex, 0) + v_can_CDA2;
          v_mto_CDA2ex  := nvl(v_mto_CDA2ex, 0) + v_mto_CDA2;
        END LOOP;

        insert into sb_dep_ins_captacion
          (fecha,
           cod_moneda,
           tip_persona,
           can_cta_corrientes,
           mto_cta_corrientes,
           can_ah_vistas,
           mto_ah_vistas,
           can_plz_fijo1,
           mto_pla_fijo1,
           can_plz_fijo2,
           mto_plz_fijo2,
           can_ah_certificados1,
           mto_ah_certificados1,
           can_ah_certificados2,
           mto_ah_certificados2)
        values
          (pag_cal.fu_obt_fec_actual(3),
           'X',
           v_persona,
           v_can_CTAS,
           v_mto_CTAS,
           v_can_vistaex,
           v_mto_vistaex,
           v_can_TIF1ex,
           v_mto_TIF1ex,
           v_can_TIF2ex,
           v_mto_TIF2ex,
           v_can_CDA1ex,
           v_mto_CDA1ex,
           v_can_CDA2ex,
           v_mto_CDA2ex);
      end loop;
    END;
    PROCEDURE LP_CAL_DEP_MON_LOCAL IS
      v_mto_vista1    ah_cta_vistas.sal_total%type := 0;
      v_mto_vista2    ah_cta_vistas.sal_total%type := 0;
      v_mto_vista     ah_cta_vistas.sal_total%type := 0;
      v_can_vista     number(10) := 0;
      v_can_vista1    number(10) := 0;
      v_mto_TIF1      ah_cta_vistas.sal_total%type := 0;
      v_can_TIF1      number(10) := 0;
      v_mto_TIF2      ah_cta_vistas.sal_total%type := 0;
      v_can_TIF2      number(10) := 0;
      v_mto_CDA1      ah_cta_vistas.sal_total%type := 0;
      v_can_CDA1      number(10) := 0;
      v_mto_CDA2      ah_cta_vistas.sal_total%type := 0;
      v_can_CDA2      number(10) := 0;
      v_persona       varchar2(1) := 0;
      v_mto_CTA       ah_cta_vistas.sal_total%type := 0;
      v_can_CTA       number(10) := 0;
      v_cod_mon_local ba_monedas.cod_moneda%type;
    begin
      v_cod_mon_local := pag_gen.fu_obt_mon_local;

      FOR v_contador IN 1 .. 2 LOOP
        IF v_contador = 1 then
          v_persona := 'F';
        else
          v_persona := 'J';
        end if;
        /* Depositantes por vista, moneda local - personas físicas */
        select round(nvl(sum(decode(ah.est_cer_batch,
                                    'V',
                                    ah.sal_tot_batch,
                                    'P',
                                    ah.sal_tot_batch,
                                    ah.sal_tot_batch - ah.capital)) / 1000,
                         0),
                     0),
               count(distinct pe.cod_persona)
          into v_mto_vista2, v_can_vista1
          from ah_cta_certificados ah, ge_cta_clientes cl, ba_personas pe
         where est_batch NOT IN ('T', 'A', 'C', 'X')
           and (est_cer_batch in ('V', 'P') or sal_tot_batch > capital)
           and cod_moneda = v_cod_mon_local
           and cl.nro_cuenta = ah.nro_cuenta
           and pe.cod_persona = cl.cod_persona
           and pe.tipo = v_persona
           and cl.relacion = 'P';
        select round(nvl(sum(sal_tot_batch) / 1000, 0), 0),
               count(distinct pe.cod_persona)
          into v_mto_vista, v_can_vista
          from ah_cta_vistas ah, ge_cta_clientes cl, ba_personas pe
         where cod_moneda = v_cod_mon_local
           and est_batch not in ('A', 'C')
           and cl.nro_cuenta = ah.nro_cuenta
           and pe.cod_persona = cl.cod_persona
           and pe.tipo = v_persona
           and cl.relacion = 'P'; --Abierta y cancelada
        v_mto_vista := nvl(v_mto_vista, 0) + nvl(v_mto_vista2, 0);
        v_can_vista := v_can_vista + v_can_vista1;
        /* Depositantes por título */
        -- Plazo  <= 90 días
        select round(nvl(sum(capital) / 1000, 0), 0),
               count(distinct pe.cod_persona)
          into v_mto_TIF1, v_can_TIF1
          from ah_cta_certificados ah,
               ge_clientes         c,
               ge_cta_clientes     cl,
               ba_personas         pe
         where fec_vencimiento - fec_apertura <= 90
           and (c.cod_sec_contable = 'F' or ah.cod_modalidad = 34)
           and c.cod_persona = cl.cod_persona
           and est_cer_batch not in ('V', 'P')
           and est_batch NOT IN ('T', 'A', 'C', 'X')
           and cod_moneda = v_cod_mon_local
           and cl.nro_cuenta = ah.nro_cuenta
           and pe.cod_persona = cl.cod_persona
           and pe.tipo = v_persona
           and cl.relacion = 'P';
        -- Plazo  > 90 días
        select round(nvl(sum(capital) / 1000, 0), 0),
               count(distinct pe.cod_persona)
          into v_mto_TIF2, v_can_TIF2
          from ah_cta_certificados ah,
               ge_clientes         c,
               ge_cta_clientes     cl,
               ba_personas         pe
         where fec_vencimiento - fec_apertura > 90
           and (c.cod_sec_contable = 'F' or ah.cod_modalidad = 34)
           and c.cod_persona = cl.cod_persona
           and est_cer_batch not in ('V', 'P')
           and est_batch NOT IN ('T', 'A', 'C', 'X')
           and cod_moneda = v_cod_mon_local
           and cl.nro_cuenta = ah.nro_cuenta
           and pe.cod_persona = cl.cod_persona
           and pe.tipo = v_persona
           and cl.relacion = 'P';
        /* Calcula CDA */
        -- Plazo  Menor o igual a 360 días
        select round(nvl(sum(capital) / 1000, 0), 0),
               count(distinct pe.cod_persona)
          into v_mto_CDA1, v_can_CDA1
          from ah_cta_certificados ah,
               ge_clientes         c,
               ge_cta_clientes     cl,
               ba_personas         pe
         where fec_vencimiento - fec_apertura <= 360
           and est_cer_batch not in ('V', 'P')
           and ah.cod_modalidad = 33
           and c.cod_sec_contable <> 'F'
           and c.cod_persona = cl.cod_persona
           and est_batch NOT IN ('T', 'A', 'C', 'X')
           and cod_moneda = v_cod_mon_local
           and cl.nro_cuenta = ah.nro_cuenta
           and pe.cod_persona = cl.cod_persona
           and pe.tipo = v_persona
           and cl.relacion = 'P';
        -- Calcula total de personas x CDA <= 360
        -- Plazo  Mayor a 360 días
        select round(nvl(sum(capital) / 1000, 0), 0),
               count(distinct pe.cod_persona)
          into v_mto_CDA2, v_can_CDA2
          from ah_cta_certificados ah,
               ge_clientes         c,
               ge_cta_clientes     cl,
               ba_personas         pe
         where fec_vencimiento - fec_apertura > 360
           and est_cer_batch not in ('V', 'P')
           and ah.cod_modalidad = 33
           and c.cod_sec_contable <> 'F'
           and c.cod_persona = cl.cod_persona
           and est_batch NOT IN ('T', 'A', 'C', 'X')
           and cod_moneda = v_cod_mon_local
           and cl.nro_cuenta = ah.nro_cuenta
           and pe.cod_persona = cl.cod_persona
           and pe.tipo = v_persona
           and cl.relacion = 'P';
        /* Calcula CTA. CTE. */
        -- Monto
        select round(nvl(sum(sal_total) / 1000, 0), 0),
               count(distinct pe.cod_persona)
          into v_mto_CTA, v_can_CTA
          from cc_cta_corrientes ah, ge_cta_clientes cl, ba_personas pe
         where est_batch not in ('V', 'P')
           and ah.cod_modalidad = 41
           and est_batch NOT IN ('T', 'A', 'C', 'X')
           and cod_moneda = v_cod_mon_local
           and cl.nro_cuenta = ah.nro_cuenta
           and pe.cod_persona = cl.cod_persona
           and pe.tipo = v_persona
           and cl.relacion = 'P';
        insert into sb_dep_ins_captacion
          (fecha,
           cod_moneda,
           tip_persona,
           can_cta_corrientes,
           mto_cta_corrientes,
           can_ah_vistas,
           mto_ah_vistas,
           can_plz_fijo1,
           mto_pla_fijo1,
           can_plz_fijo2,
           mto_plz_fijo2,
           can_ah_certificados1,
           mto_ah_certificados1,
           can_ah_certificados2,
           mto_ah_certificados2)
        values
          (pag_cal.fu_obt_fec_actual(3),
           pag_gen.fu_obt_mon_local,
           v_persona,
           v_can_CTA,
           v_mto_CTA,
           v_can_vista,
           v_mto_vista,
           v_can_TIF1,
           v_mto_TIF1,
           v_can_TIF2,
           v_mto_TIF2,
           v_can_CDA1,
           v_mto_CDA1,
           v_can_CDA2,
           v_mto_CDA2);
        commit;
      END LOOP;
    END LP_CAL_DEP_MON_LOCAL;
  Begin
    lp_cal_dep_mon_local;
    lp_cal_dep_mon_extr;
  End;
  /* Generar archivos ASCII del fonde de garantías. */
  PROCEDURE PR_GEN_FDG_ASCII(P_FECHA IN DATE default null) IS
    --- Variables del proceso
    v_fec_proceso ge_calendarios.fec_actual%type;
    v_mes_proceso varchar2(06);
    v_nom_ascii   varchar2(16);
    v_cod_entidad ge_par_generales.cod_entidad%type;
    v_directorio  varchar2(100);
    --- Cursor de personas
    CURSOR c_personas IS
      SELECT cod_persona,
             ind_exclusion,
             abr_documento,
             nro_documento,
             ape_raz_social,
             nombres
        FROM sb_fdg_personas
       WHERE fecha = v_fec_proceso;
    CURSOR c_depositos IS
      SELECT NRO_CUENTA,
             MOD_SUP_RUBRO,
             CERTIFICADO,
             IND_IMP_JUDICIAL,
             CAN_TITULARES,
             COD_MON_BCO_CENTRAL,
             CAPITAL_EXT,
             INT_DEVENGADO_EXT,
             TOTAL_EXT,
             CAPITAL,
             INT_DEVENGADO,
             TOTAL
        FROM sb_fdg_depositos
       WHERE fecha = v_fec_proceso;
    CURSOR c_dep_personas IS
      SELECT cod_persona, nro_cuenta
        FROM sb_fdg_dep_personas
       WHERE fecha = v_fec_proceso;
    CURSOR c_deudas IS
      SELECT NRO_CUENTA,
             CAN_TITULARES,
             COD_MON_BCO_CENTRAL,
             CAPITAL_EXT,
             INT_DEVENGADO_EXT,
             TOTAL_EXT,
             CAPITAL,
             INT_DEVENGADO,
             TOTAL
        FROM sb_fdg_deudas
       WHERE fecha = v_fec_proceso;
    CURSOR c_deu_personas IS
      SELECT cod_persona, nro_cuenta
        FROM sb_fdg_deu_personas
       WHERE fecha = v_fec_proceso;
    CURSOR c_datos IS
      SELECT ref_archivo, can_registros
        FROM sb_fdg_datos
       WHERE fecha = v_fec_proceso;
    --- Lineas ASCII
    v_archivo          utl_file.file_type;
    v_lin_personas     varchar2(179);
    v_lin_depositos    varchar2(154);
    v_lin_dep_personas varchar2(44);
    v_lin_deudas       varchar2(132);
    v_lin_deu_personas varchar2(44);
    v_lin_datos        varchar2(11);
    --- Variables Datos ---
    v_ref_personas     sb_fdg_datos.ref_archivo%type;
    v_can_personas     sb_fdg_datos.can_registros%type;
    v_ref_depositos    sb_fdg_datos.ref_archivo%type;
    v_can_depositos    sb_fdg_datos.can_registros%type;
    v_ref_dep_personas sb_fdg_datos.ref_archivo%type;
    v_can_dep_personas sb_fdg_datos.can_registros%type;
    v_ref_deudas       sb_fdg_datos.ref_archivo%type;
    v_can_deudas       sb_fdg_datos.can_registros%type;
    v_ref_deu_personas sb_fdg_datos.ref_archivo%type;
    v_can_deu_personas sb_fdg_datos.can_registros%type;
  BEGIN
    If p_fecha is not null Then
      v_fec_proceso := p_fecha;
    Else
      v_fec_proceso := pag_cal.fu_obt_fec_actual(3);
    End If;
    v_mes_proceso := to_char(v_fec_proceso, 'YYYYMM');
    v_directorio  := fug_obt_pardinamico('DIR_REP_FTP');
    BEGIN
      select cod_entidad
        into v_cod_entidad
        from ge_par_generales
       where rownum = 1;
    exception
      when others then
        raise_application_error(-20000,
                                'No existen parametros generales de la Entidad definidos');
    END;
    if utl_file.is_open(v_archivo) then
      utl_file.fclose(v_archivo);
    end if;
    --- Procesar archivo personas PS
    v_nom_ascii    := v_cod_entidad || v_mes_proceso || 'PS.txt';
    v_archivo      := utl_file.fopen(v_directorio, v_nom_ascii, 'w');
    v_can_personas := 0;
    FOR r_per IN c_personas LOOP
      -- v_lin_personas := r_per.COD_ENTIDAD;
      v_lin_personas := rpad(r_per.cod_persona, 20, ' ');
      v_lin_personas := v_lin_personas || r_per.ind_exclusion;
      v_lin_personas := v_lin_personas || rpad(r_per.abr_documento, 3, ' ');
      v_lin_personas := v_lin_personas ||
                        rpad(r_per.nro_documento, 20, ' ');
      v_lin_personas := v_lin_personas ||
                        rpad(r_per.ape_raz_social, 100, ' ');
      v_lin_personas := v_lin_personas ||
                        rpad(nvl(r_per.nombres, ' '), 30, ' ');
      utl_file.put_line(v_archivo, v_lin_personas);
      v_can_personas := v_can_personas + 1;
    END LOOP;
    utl_file.fclose(v_archivo);
    --- Procesar archivo depósitos DP
    v_nom_ascii     := v_cod_entidad || v_mes_proceso || 'DP.txt';
    v_archivo       := utl_file.fopen(v_directorio, v_nom_ascii, 'w');
    v_can_depositos := 0;
    FOR r_dep IN c_depositos LOOP
      v_lin_depositos := rpad(r_dep.nro_cuenta, 20, ' ');
      v_lin_depositos := v_lin_depositos ||
                         rpad(r_dep.mod_sup_rubro, 6, ' ');
      v_lin_depositos := v_lin_depositos ||
                         rpad(nvl(r_dep.certificado, ' '), 15, ' ');
      v_lin_depositos := v_lin_depositos || r_dep.ind_imp_judicial;
      v_lin_depositos := v_lin_depositos ||
                         lpad(r_dep.can_titulares, 2, ' ');
      v_lin_depositos := v_lin_depositos ||
                         rpad(r_dep.cod_mon_bco_central, 4, ' ');
      v_lin_depositos := v_lin_depositos ||
                         lpad(r_dep.capital_ext, 17, ' ');
      v_lin_depositos := v_lin_depositos ||
                         lpad(r_dep.INT_DEVENGADO_EXT, 17, ' ');
      v_lin_depositos := v_lin_depositos || lpad(r_dep.TOTAL_EXT, 17, ' ');
      v_lin_depositos := v_lin_depositos || lpad(r_dep.CAPITAL, 17, ' ');
      v_lin_depositos := v_lin_depositos ||
                         lpad(r_dep.INT_DEVENGADO, 17, ' ');
      v_lin_depositos := v_lin_depositos || lpad(r_dep.TOTAL, 17, ' ');
      utl_file.put_line(v_archivo, v_lin_depositos);
      v_can_depositos := v_can_depositos + 1;
    END LOOP;
    utl_file.fclose(v_archivo);
    --- Procesar archivo personas depósitos PD
    v_nom_ascii        := v_cod_entidad || v_mes_proceso || 'PD.txt';
    v_archivo          := utl_file.fopen(v_directorio, v_nom_ascii, 'w');
    v_can_dep_personas := 0;
    FOR r_dpe IN c_dep_personas LOOP
      v_lin_dep_personas := rpad(r_dpe.COD_PERSONA, 20, ' ');
      v_lin_dep_personas := v_lin_dep_personas ||
                            rpad(r_dpe.NRO_CUENTA, 20, ' ');
      utl_file.put_line(v_archivo, v_lin_dep_personas);
      v_can_dep_personas := v_can_dep_personas + 1;
    END LOOP;
    utl_file.fclose(v_archivo);
    --- Procesar archivo deudas DU
    v_nom_ascii  := v_cod_entidad || v_mes_proceso || 'DU.txt';
    v_archivo    := utl_file.fopen(v_directorio, v_nom_ascii, 'w');
    v_can_deudas := 0;
    FOR r_deu IN c_deudas LOOP
      v_lin_deudas := rpad(r_deu.NRO_CUENTA, 20, ' ');
      v_lin_deudas := v_lin_deudas || lpad(r_deu.CAN_TITULARES, 2, ' ');
      v_lin_deudas := v_lin_deudas ||
                      rpad(r_deu.COD_MON_BCO_CENTRAL, 4, ' ');
      v_lin_deudas := v_lin_deudas || lpad(r_deu.CAPITAL_EXT, 17, ' ');
      v_lin_deudas := v_lin_deudas ||
                      lpad(r_deu.INT_DEVENGADO_EXT, 17, ' ');
      v_lin_deudas := v_lin_deudas || lpad(r_deu.TOTAL_EXT, 17, ' ');
      v_lin_deudas := v_lin_deudas || lpad(r_deu.CAPITAL, 17, ' ');
      v_lin_deudas := v_lin_deudas || lpad(r_deu.INT_DEVENGADO, 17, ' ');
      v_lin_deudas := v_lin_deudas || lpad(r_deu.TOTAL, 17, ' ');
      utl_file.put_line(v_archivo, v_lin_deudas);
      v_can_deudas := v_can_deudas + 1;
    END LOOP;
    utl_file.fclose(v_archivo);
    --- Procesar archivo deudas personas PU
    v_nom_ascii        := v_cod_entidad || v_mes_proceso || 'PU.txt';
    v_archivo          := utl_file.fopen(v_directorio, v_nom_ascii, 'w');
    v_can_deu_personas := 0;
    FOR r_dup IN c_deu_personas LOOP
      v_lin_deu_personas := rpad(r_dup.COD_PERSONA, 20, ' ');
      v_lin_deu_personas := v_lin_deu_personas ||
                            rpad(r_dup.NRO_CUENTA, 20, ' ');
      utl_file.put_line(v_archivo, v_lin_deu_personas);
      v_can_deu_personas := v_can_deu_personas + 1;
    END LOOP;
    utl_file.fclose(v_archivo);

    --Regenerar Datos de Tablas--
    v_ref_personas     := 'PS';
    v_ref_depositos    := 'DP';
    v_ref_dep_personas := 'PD';
    v_ref_deudas       := 'DU';
    v_ref_deu_personas := 'PU';

    delete sb_fdg_datos where fecha = v_fec_proceso;
    Insert into sb_fdg_datos
      (ref_archivo, can_registros, fecha)
    values
      (v_ref_personas, v_can_personas, v_fec_proceso);
    Insert into sb_fdg_datos
      (ref_archivo, can_registros, fecha)
    values
      (v_ref_depositos, v_can_depositos, v_fec_proceso);
    Insert into sb_fdg_datos
      (ref_archivo, can_registros, fecha)
    values
      (v_ref_dep_personas, v_can_dep_personas, v_fec_proceso);
    Insert into sb_fdg_datos
      (ref_archivo, can_registros, fecha)
    values
      (v_ref_deudas, v_can_deudas, v_fec_proceso);
    Insert into sb_fdg_datos
      (ref_archivo, can_registros, fecha)
    values
      (v_ref_deu_personas, v_can_deu_personas, v_fec_proceso);

    --- Procesar archivo datos DA
    v_nom_ascii := v_cod_entidad || v_mes_proceso || 'DA.txt';
    v_archivo   := utl_file.fopen(v_directorio, v_nom_ascii, 'w');
    FOR r_dat IN c_datos LOOP
      v_lin_datos := r_dat.REF_ARCHIVO;
      v_lin_datos := v_lin_datos || lpad(r_dat.CAN_REGISTROS, 6, ' ');
      utl_file.put_line(v_archivo, v_lin_datos);
    END LOOP;
    utl_file.fclose(v_archivo);

  EXCEPTION
    when no_data_found then
      --- Fin del archivo
      utl_file.fclose(v_archivo);
    when utl_file.invalid_path THEN
      utl_file.fclose(v_archivo);
      raise_application_error(-20000, 'Directorio invalido');
    when utl_file.invalid_mode THEN
      utl_file.fclose(v_archivo);
      raise_application_error(-20000, 'Modo invalido');
    when utl_file.invalid_filehandle THEN
      utl_file.fclose(v_archivo);
      raise_application_error(-20000, 'Invalida Filehandle');
    when utl_file.invalid_operation THEN
      --- Fin del archivo
      utl_file.fclose(v_archivo);
    when utl_file.read_error THEN
      utl_file.fclose(v_archivo);
      raise_application_error(-20000, 'Lectura errada');
    when utl_file.write_error THEN
      utl_file.fclose(v_archivo);
      raise_application_error(-20000, 'Escritura errada');
    when utl_file.internal_error THEN
      utl_file.fclose(v_archivo);
      raise_application_error(-20000, 'Error interno');
  END;
  Procedure PR_FON_GARANTIA Is
    -- Definición de Variables
    v_nro_cuenta           sb_fdg_depositos.nro_cuenta%Type;
    v_fec_actual           ge_calendarios.fec_actual%Type;
    v_fec_ant_habil        ge_calendarios.fec_anterior%Type;
    v_cod_oficina          ba_oficinas.cod_oficina%Type;
    v_insertado            Varchar2(1);
    v_cod_gru_economico    ge_clientes.cod_gru_economico%Type;
    v_cod_cau_embargo      ge_bloqueos.cod_causa%type;
    v_cod_cau_blo_garantia ge_bloqueos.cod_causa%type;
    -- Cursor de Personas
    Cursor c_per Is
      Select v_fec_actual,
             cl.cod_persona,
             decode(v_cod_gru_economico,
                    Null,
                    0,
                    decode(v_cod_gru_economico, cl.cod_gru_economico, 1, 0)) ind_exclusion,
             td.abreviatura,
             pe.nro_documento,
             substr(decode(pe.tipo,
                           'F',
                           pf.pri_apellido || ' ' || pf.seg_apellido,
                           'J',
                           pj.raz_social),
                    1,
                    100) ape_raz_social,
             substr(decode(pe.tipo,
                           'F',
                           pf.pri_nombre || ' ' || pf.seg_nombre,
                           'J',
                           ''),
                    1,
                    30) nombres,
             Null ui,
             Null fi,
             Null um,
             Null fm
        From ba_per_juridicas  pj,
             ba_per_fisicas    pf,
             ba_tip_documentos td,
             ba_personas       pe,
             ge_clientes       cl
       Where pj.cod_persona(+) = pe.cod_persona
         And pf.cod_persona(+) = pe.cod_persona
         And td.cod_tip_documento = pe.cod_tip_documento
         And pe.cod_persona = cl.cod_persona
         And (Exists (Select '1'
                 From ah_cta_certificados ct, ge_cta_clientes cc
                Where cc.nro_cuenta = ct.nro_cuenta
                  And ct.estado Not In ('A', 'C', 'T')
                  And cc.cod_persona = cl.cod_persona
                  And ct.sal_total > 0 -- *1
                     --agregado para quitar los retenidos--
                  And nvl(ct.sal_ret_batch, 0) = 0
                     --------------------------------------
                  And cc.relacion = 'P') Or Exists
              (Select '1'
                 From ah_cta_vistas ct, ge_cta_clientes cc
                Where cc.nro_cuenta = ct.nro_cuenta
                  And ct.estado Not In ('A')
                  And cc.cod_persona = cl.cod_persona
                  And (ct.sal_total <> 0 Or ct.sal_retenido <> 0 Or
                      ct.sal_bloqueado <> 0)
                  And cc.relacion = 'P') Or Exists
              (Select '1'
                 From cc_cta_corrientes ct, ge_cta_clientes cc
                Where cc.nro_cuenta = ct.nro_cuenta
                  And ct.estado Not In ('A', 'T')
                  And cc.cod_persona = cl.cod_persona
                  And ct.sal_total != 0 -- *1
                  And cc.relacion = 'P') Or Exists
              (Select '1'
                 From cc_cta_bancarias ct, ge_cta_clientes cc
                Where cc.nro_cuenta = ct.nro_cuenta
                  And ct.estado Not In ('A', 'C', 'T')
                  And cc.cod_persona = cl.cod_persona
                  And ct.sal_total > 0 -- *1
                  And cc.relacion = 'P'));
    -- Cursor de Depósitos
    Cursor c_dep Is
      Select ah.nro_cuenta,
             ah.serie || '-' || ah.nro_certificado certificado,
             ah.cod_moneda,
             (nvl(sal_tot_batch, 0) - nvl(sal_ret_batch, 0)) -
             (Select nvl(Sum(mto_interes), 0)
                From ah_cupones
               Where nro_cuenta = ah.nro_cuenta
                 And estado = 'V') capital,
             nvl((nvl(pas_bcp.fu_obt_dev_cda(ah.nro_cuenta,
                                             ah.capital,
                                             ah.fec_apertura,
                                             v_fec_actual),
                      0)),
                 0) int_devengado,
             cl.cod_tip_deudor,
             cl.cod_sec_contable,
             cl.residente,
             substr(Replace(ta.cod_rubro,
                            'TD',
                            Trim(to_char(cl.cod_tip_deudor, '09'))),
                    6,
                    3) || '0' || -- Plazo
             substr(Replace(ta.cod_rubro,
                            'TD',
                            Trim(to_char(cl.cod_tip_deudor, '09'))),
                    9,
                    2) mod_sup_rubro,
             mo.cod_mon_bco_central
        From ba_monedas          mo,
             ge_plz_contables    pl,
             ge_tip_asientos     ta,
             ge_transacciones    tr,
             ge_clientes         cl,
             ge_cta_clientes     cc,
             ah_cta_certificados ah,
             sb_fdg_personas     sp
       Where mo.cod_moneda = ah.cod_moneda
         And ta.cod_tip_asiento = tr.cod_tip_asiento
         And tr.cod_transaccion = 602
         And tr.cod_modulo = cc.cod_modulo
         And tr.cod_modalidad = cc.cod_modalidad
         And ta.tip_movimiento = 'C'
         And ta.cod_moneda = ah.cod_moneda
         And cl.cod_persona = cc.cod_persona
         And nvl(ta.cod_sec_contable, cl.cod_sec_contable) =
             cl.cod_sec_contable
         And decode(ta.ind_residente, 'X', cl.residente, ta.ind_residente) =
             cl.residente
         And pl.can_dias =
             (Select Min(can_dias)
                From ge_plz_contables
               Where can_dias >= (ah.fec_vencimiento - ah.fec_apertura + 1))
         And cc.nro_cuenta = ah.nro_cuenta
         And ah.est_batch Not In ('A', 'C', 'T')
         And ah.est_cer_batch Not In ('V', 'P')
         And ah.sal_total > 0
            --------------------------------------
         And cc.cod_persona = sp.cod_persona
         And cc.relacion = 'P'
         And ah.cod_modalidad != 36 --AP 2686 se excluye mod.36 Bonos Subordinados
         And sp.fecha = v_fec_actual
      Union -- Certificados Vencidos
      Select ah.nro_cuenta,
             ah.serie || '-' || ah.nro_certificado certificado,
             ah.cod_moneda,
             nvl((decode(ah.est_cer_batch,
                         'V',
                         ah.sal_tot_batch,
                         'P',
                         ah.sal_tot_batch,
                         ah.sal_tot_batch - ah.capital)),
                 0) capital,
             nvl((nvl(pas_bcp.fu_obt_dev_cda(ah.nro_cuenta,
                                             ah.capital,
                                             ah.fec_apertura,
                                             v_fec_actual),
                      0)),
                 0) int_devengado,
             cl.cod_tip_deudor,
             cl.cod_sec_contable,
             cl.residente,
             substr(Replace(ta.cod_rubro,
                            'TD',
                            Trim(to_char(cl.cod_tip_deudor, '09'))),
                    6,
                    3) || '0' || -- Plazo
             substr(Replace(ta.cod_rubro,
                            'TD',
                            Trim(to_char(cl.cod_tip_deudor, '09'))),
                    9,
                    2) mod_sup_rubro,
             mo.cod_mon_bco_central
        From ba_monedas          mo,
             ge_plz_contables    pl,
             ge_tip_asientos     ta,
             ge_transacciones    tr,
             ge_clientes         cl,
             ge_cta_clientes     cc,
             ah_cta_certificados ah,
             sb_fdg_personas     sp
       Where mo.cod_moneda = ah.cod_moneda
         And ta.cod_tip_asiento = tr.cod_tip_asiento
         And tr.cod_transaccion = 604
         And tr.cod_modulo = cc.cod_modulo
         And tr.cod_modalidad = cc.cod_modalidad
         And ta.tip_movimiento = 'C'
         And ta.cod_moneda = ah.cod_moneda
         And cl.cod_persona = cc.cod_persona
         And nvl(ta.cod_sec_contable, cl.cod_sec_contable) =
             cl.cod_sec_contable
         And decode(ta.ind_residente, 'X', cl.residente, ta.ind_residente) =
             cl.residente
         And pl.can_dias =
             (Select Min(can_dias)
                From ge_plz_contables
               Where can_dias >= (ah.fec_vencimiento - ah.fec_apertura + 1))
         And cc.nro_cuenta = ah.nro_cuenta
         And ah.est_batch Not In ('A', 'C', 'T')
         And (ah.est_cer_batch In ('V', 'P'))
         And ah.sal_total > 0
         And cc.cod_persona = sp.cod_persona
         And cc.relacion = 'P'
         And ah.cod_modalidad != 36 --AP 2686 se excluye mod.36 Bonos Subordinados
         And sp.fecha = v_fec_actual
      Union -- Intereses Vencidos de CDA
      Select substr(ah.nro_cuenta || '-' || ah.serie, 1, 20) nro_cuenta,
             ah.serie || '-' || ah.nro_certificado certificado,
             ah.cod_moneda,
             nvl(Sum(ahc.mto_interes), 0) capital,
             nvl((nvl(pas_bcp.fu_obt_dev_cda(ah.nro_cuenta,
                                             ah.capital,
                                             ah.fec_apertura,
                                             to_date('29/07/2011',
                                                     'dd/mm/yyyy')),
                      0)),
                 0) int_devengado,
             cl.cod_tip_deudor,
             cl.cod_sec_contable,
             cl.residente,
             substr(Replace(ta.cod_rubro,
                            'TD',
                            Trim(to_char(cl.cod_tip_deudor, '09'))),
                    6,
                    3) || '0' || -- Plazo
             substr(Replace(ta.cod_rubro,
                            'TD',
                            Trim(to_char(cl.cod_tip_deudor, '09'))),
                    9,
                    2) mod_sup_rubro,
             mo.cod_mon_bco_central
        From ba_monedas          mo,
             ge_plz_contables    pl,
             ge_tip_asientos     ta,
             ge_transacciones    tr,
             ge_clientes         cl,
             ge_cta_clientes     cc,
             ah_cta_certificados ah,
             ah_cupones          ahc,
             sb_fdg_personas     sp
       Where mo.cod_moneda = ah.cod_moneda
         And ta.cod_tip_asiento = tr.cod_tip_asiento
         And tr.cod_transaccion = 604
         And tr.cod_modulo = cc.cod_modulo
         And tr.cod_modalidad = cc.cod_modalidad
         And ta.tip_movimiento = 'C'
         And ta.cod_moneda = ah.cod_moneda
         And cl.cod_persona = cc.cod_persona
         And nvl(ta.cod_sec_contable, cl.cod_sec_contable) =
             cl.cod_sec_contable
         And decode(ta.ind_residente, 'X', cl.residente, ta.ind_residente) =
             cl.residente
         And pl.can_dias =
             (Select Min(can_dias)
                From ge_plz_contables
               Where can_dias >= (ah.fec_vencimiento - ah.fec_apertura + 1))
         And cc.nro_cuenta = ah.nro_cuenta
         And ah.est_batch Not In ('A', 'C', 'T')
         And (ah.est_cer_batch Not In ('V', 'P'))
         And ah.sal_total > 0
            --------------------------------------
         And cc.cod_persona = sp.cod_persona
         And cc.relacion = 'P'
         And ah.nro_cuenta = ahc.nro_cuenta
         And ahc.estado = 'V'
         And ah.cod_modalidad != 36 --AP 2686 se excluye mod.36 Bonos Subordinados
         And sp.fecha = v_fec_actual
       Group By substr(ah.nro_cuenta || '-' || ah.serie, 1, 20),
                ah.serie || '-' || ah.nro_certificado,
                ah.cod_moneda,
                nvl((nvl(pas_bcp.fu_obt_dev_cda(ah.nro_cuenta,
                                                ah.capital,
                                                ah.fec_apertura,
                                                to_date('29/07/2011',
                                                        'dd/mm/yyyy')),
                         0)),
                    0),
                cl.cod_tip_deudor,
                cl.cod_sec_contable,
                cl.residente,
                substr(Replace(ta.cod_rubro,
                               'TD',
                               Trim(to_char(cl.cod_tip_deudor, '09'))),
                       6,
                       3) || '0' || -- Plazo
                substr(Replace(ta.cod_rubro,
                               'TD',
                               Trim(to_char(cl.cod_tip_deudor, '09'))),
                       9,
                       2),
                mo.cod_mon_bco_central
      Union
      Select v.nro_cuenta,
             v.certificado,
             v.cod_moneda,
             v.capital,
             v.int_devengado,
             v.cod_tip_deudor,
             v.cod_sec_contable,
             v.residente,
             substr(v.cod_rubro, 6, 3) || '0' || substr(v.cod_rubro, 9, 2) mod_sup_rubro,
             v.cod_mon_bco_central
        From (Select ah.nro_cuenta,
                     '' certificado,
                     ah.cod_moneda,
                     nvl((ah.sal_tot_batch), 0) - nvl(ah.sal_ret_batch, 0) -
                     nvl(em.mon_embargo, 0) capital,
                     (Case
                       When decode(v_fec_actual,
                                   ah.fec_ult_capitalizacion,
                                   0,
                                   nvl((nvl(pas_bcp.fu_obt_dev_av(ah.nro_cuenta,
                                                                  v_fec_actual),
                                            0)),
                                       0)) < 0 Then
                        0
                       Else
                        decode(v_fec_actual,
                               ah.fec_ult_capitalizacion,
                               0,
                               nvl((nvl(pas_bcp.fu_obt_dev_av(ah.nro_cuenta,
                                                              v_fec_actual),
                                        0)),
                                   0))
                     End) int_devengado,
                     cl.cod_tip_deudor,
                     cl.cod_sec_contable,
                     cl.residente,
                     fub_obt_rub_transaccion(ah.cod_modulo,
                                             ah.cod_modalidad,
                                             decode(ah.cta_combinada,
                                                    'N',
                                                    602,
                                                    682),
                                             ah.cod_moneda,
                                             cl.cod_persona,
                                             to_char('1'),
                                             'C') cod_rubro,
                     mo.cod_mon_bco_central
                From ba_monedas mo,
                     ge_clientes cl,
                     ge_cta_clientes cc,
                     ah_cta_vistas ah,
                     sb_fdg_personas sp,
                     (select e.nro_cuenta, sum(nvl(e.monto, 0)) mon_embargo
                        from ge_bloqueos e
                       where e.cod_causa = v_cod_cau_embargo
                       group by e.nro_cuenta) em
               Where mo.cod_moneda = ah.cod_moneda
                 And cl.cod_persona = cc.cod_persona
                 And cc.nro_cuenta = ah.nro_cuenta
                 And ah.est_batch Not In ('A')
                 And (ah.sal_tot_batch <> 0 Or ah.sal_ret_batch <> 0 Or
                     ah.sal_blo_batch <> 0)
                 And cc.cod_persona = sp.cod_persona
                 And cc.relacion = 'P'
                 and cc.nro_cuenta = em.nro_cuenta(+)
                 And sp.fecha = v_fec_actual) v
      Union
      Select x.nro_cuenta,
             x.certificado,
             x.cod_moneda,
             x.capital,
             x.int_devengado,
             x.cod_tip_deudor,
             x.cod_sec_contable,
             x.residente,
             substr(x.cod_rubro, 6, 3) || '0' || substr(x.cod_rubro, 9, 2) mod_sup_rubro,
             x.cod_mon_bco_central

        From (Select ct.nro_cuenta,
                     '' certificado,
                     ct.cod_moneda,
                     (Case
                       When (nvl((ct.sal_tot_batch), 0) -
                            nvl(ct.sal_blo_batch, 0) -
                            nvl(ct.sal_ret_batch, 0)) > 0 And
                            nvl(ct.sal_blo_batch, 0) = 0 Then
                        (nvl((ct.sal_tot_batch), 0) -
                        nvl(ct.sal_blo_batch, 0) - nvl(ct.sal_ret_batch, 0))
                       When (nvl((ct.sal_tot_batch), 0) -
                            nvl(ct.sal_blo_batch, 0) -
                            nvl(ct.sal_ret_batch, 0)) > 0 And
                            nvl(ct.sal_blo_batch, 0) > 0 Then
                        (nvl((ct.sal_tot_batch), 0) -
                        nvl(ct.sal_ret_batch, 0)) - nvl(em.mon_embargo, 0)
                       When (nvl((ct.sal_tot_batch), 0) -
                            nvl(ct.sal_blo_batch, 0) -
                            nvl(ct.sal_ret_batch, 0)) < 0 And
                            nvl(ct.sal_blo_batch, 0) > 0 Then
                        nvl(ct.sal_blo_batch, 0) - nvl(em.mon_embargo, 0)
                       When (nvl((ct.sal_tot_batch), 0) -
                            nvl(ct.sal_blo_batch, 0) -
                            nvl(ct.sal_ret_batch, 0)) = 0 And
                            nvl(ct.sal_blo_batch, 0) > 0 Then
                        nvl(ct.sal_blo_batch, 0) - nvl(em.mon_embargo, 0)
                       When (nvl((ct.sal_tot_batch), 0) -
                            nvl(ct.sal_blo_batch, 0) -
                            nvl(ct.sal_ret_batch, 0)) < 0 And
                            nvl(ct.sal_blo_batch, 0) = 0 Then
                        0
                       When (nvl((ct.sal_tot_batch), 0) -
                            nvl(ct.sal_blo_batch, 0) -
                            nvl(ct.sal_ret_batch, 0)) = 0 And
                            nvl(ct.sal_blo_batch, 0) = 0 Then
                        0
                       Else
                        0
                     End) capital,
                     0 int_devengado,
                     cl.cod_tip_deudor,
                     cl.cod_sec_contable,
                     cl.residente,
                     fub_obt_rub_transaccion(ct.cod_modulo,
                                             ct.cod_modalidad,
                                             602,
                                             ct.cod_moneda,
                                             cl.cod_persona,
                                             '1',
                                             'C') cod_rubro,
                     mo.cod_mon_bco_central
                From ba_monedas mo,
                     ge_clientes cl,
                     ge_cta_clientes cc,
                     cc_cta_corrientes ct,
                     sb_fdg_personas sp,
                     (select e.nro_cuenta, sum(nvl(e.monto, 0)) mon_embargo
                        from ge_bloqueos e
                       where e.cod_causa = v_cod_cau_embargo
                       group by e.nro_cuenta) em
               Where mo.cod_moneda = ct.cod_moneda
                 And cl.cod_persona = cc.cod_persona
                 And cc.nro_cuenta = ct.nro_cuenta
                 And ct.est_batch Not In ('A', 'T')
                 And ct.sal_total <> 0
                    --se modifico por que existen cuentas con sal_tot_batch y sal_blo_batch con los mismos montos el
                    --resultado es igual a 0(cero) y no ingresa con la condición. 12-08-2011
                 And (nvl(ct.sal_tot_batch, 0) <> 0 Or
                     nvl(ct.sal_blo_batch, 0) <> 0 Or
                     nvl(ct.sal_ret_batch, 0) <> 0)
                 And cc.cod_persona = sp.cod_persona
                 And cc.relacion = 'P'
                 And cc.nro_cuenta = em.nro_cuenta(+)
                 And sp.fecha = v_fec_actual) x
      Union
      Select x.nro_cuenta,
             x.certificado,
             x.cod_moneda,
             x.capital,
             x.int_devengado,
             x.cod_tip_deudor,
             x.cod_sec_contable,
             x.residente,
             substr(x.cod_rubro, 6, 3) || '0' || substr(x.cod_rubro, 9, 2) mod_sup_rubro,
             x.cod_mon_bco_central
        From (Select ct.nro_cuenta,
                     '' certificado,
                     ct.cod_moneda,
                     nvl((ct.sal_tot_batch), 0) - nvl(ct.sal_blo_batch, 0) -
                     nvl(ct.sal_ret_batch, 0) capital,
                     0 int_devengado,
                     cl.cod_tip_deudor,
                     cl.cod_sec_contable,
                     cl.residente,
                     fub_obt_rub_transaccion(ct.cod_modulo,
                                             '442',
                                             902,
                                             ct.cod_moneda,
                                             cl.cod_persona,
                                             '1',
                                             'C') cod_rubro,
                     mo.cod_mon_bco_central
                From ba_monedas       mo,
                     ge_clientes      cl,
                     ge_cta_clientes  cc,
                     cc_cta_bancarias ct,
                     sb_fdg_personas  sp
               Where mo.cod_moneda = ct.cod_moneda
                 And cl.cod_persona = cc.cod_persona
                 And cc.nro_cuenta = ct.nro_cuenta
                 And ct.est_batch Not In ('A', 'C', 'T')
                 And ct.sal_total > 0
                 And cc.cod_persona = sp.cod_persona
                 And (ct.cod_modalidad In (42, 48, 442) Or
                     (ct.cod_modalidad In (45) And Not Exists
                      (Select 1
                          From xv_dep_overnight xv
                         Where xv.nro_cuenta = ct.nro_cuenta
                           And xv.fecha = v_fec_ant_habil /*(Select Max(xvx.fecha)
                                                                     From xv_dep_overnight xvx
                                                                    Where xvx.nro_cuenta = ct.nro_cuenta)*/
                        )))
                 And cc.relacion = 'P'
                 And sp.fecha = v_fec_actual
              Union
              Select ct.nro_cuenta,
                     '' certificado,
                     ct.cod_moneda,
                     (nvl((ct.sal_tot_batch), 0) - nvl(ct.sal_blo_batch, 0) -
                     nvl(ct.sal_ret_batch, 0)) - nvl(xv.monto, 0) capital,
                     0 int_devengado,
                     cl.cod_tip_deudor,
                     cl.cod_sec_contable,
                     cl.residente,
                     fub_obt_rub_transaccion(ct.cod_modulo,
                                             '442',
                                             902,
                                             ct.cod_moneda,
                                             cl.cod_persona,
                                             '1',
                                             'C') cod_rubro,
                     mo.cod_mon_bco_central
                From ba_monedas       mo,
                     ge_clientes      cl,
                     ge_cta_clientes  cc,
                     cc_cta_bancarias ct,
                     sb_fdg_personas  sp,
                     xv_dep_overnight xv
               Where mo.cod_moneda = ct.cod_moneda
                 And cl.cod_persona = cc.cod_persona
                 And cc.nro_cuenta = ct.nro_cuenta
                 And ct.est_batch Not In ('A', 'C', 'T')
                 And ct.sal_total > 0
                 And cc.cod_persona = sp.cod_persona
                 And ct.cod_modalidad In (45)
                 And cc.relacion = 'P'
                 And sp.fecha = v_fec_actual
                 And ct.nro_cuenta = xv.nro_cuenta
                 And xv.fecha = v_fec_ant_habil /*(Select Max(xvx.fecha)
                                                       From xv_dep_overnight xvx
                                                      Where xvx.nro_cuenta = ct.nro_cuenta)*/
                 And (nvl((ct.sal_tot_batch), 0) - nvl(ct.sal_blo_batch, 0) -
                     nvl(ct.sal_ret_batch, 0)) - nvl(xv.monto, 0) > 0) x
      Union
      -- Cheques Ceritifcados
      Select substr(v.nro_cuenta || ' - CER', 1, 20) nro_cuenta,
             v.certificado,
             v.cod_moneda,
             nvl(v.monto, 0) capital,
             0 int_devengado,
             v.cod_tip_deudor,
             v.cod_sec_contable,
             v.residente,
             substr(v.cod_rubro, 6, 3) || '0' || substr(v.cod_rubro, 9, 2) mod_sup_rubro,
             v.cod_mon_bco_central
        From (Select ch.nro_cuenta,
                     '' certificado,
                     cc.cod_moneda,
                     ch.monto,
                     c.cod_tip_deudor,
                     c.cod_sec_contable,
                     c.residente,
                     cb.cod_rubro,
                     mo.cod_mon_bco_central
                From ba_monedas          mo,
                     cc_che_certificados ch,
                     ge_cta_clientes     gc,
                     ge_clientes         c,
                     cc_cta_corrientes   cc,
                     cc_cta_bancarias    cb,
                     sb_fdg_personas     sp
               Where ch.nro_cuenta = gc.nro_cuenta --cheque con cta-cliente
                 And gc.cod_persona = c.cod_persona --cta-cliente con cliente
                 And cc.nro_cuenta = ch.nro_cuenta --cta-corriente con che-certificado
                 And ch.nro_cta_certificado = cb.nro_cuenta
                 And ch.fec_pago Is Null
                 And mo.cod_moneda = cc.cod_moneda
                 And c.cod_persona = sp.cod_persona
                 And gc.relacion = 'P'
                 And sp.fecha = v_fec_actual) v
      Union
      -- Pignoración
      Select x.nro_cuenta,
             x.certificado,
             x.cod_moneda,
             x.capital,
             x.int_devengado,
             x.cod_tip_deudor,
             x.cod_sec_contable,
             x.residente,
             substr(x.cod_rubro, 6, 3) || '0' || substr(x.cod_rubro, 9, 2) mod_sup_rubro,
             x.cod_mon_bco_central
        From (Select substr(v.nro_cuenta || ' - PIGNO', 1, 20) nro_cuenta,
                     '' certificado,
                     ge.cod_moneda,
                     nvl(v.monto, 0) capital,
                     0 int_devengado,
                     gc.cod_tip_deudor,
                     gc.cod_sec_contable,
                     gc.residente,
                     fub_obt_rub_transaccion(ge.cod_modulo,
                                             ge.cod_modalidad,
                                             (Case
                                               When ge.cod_modalidad = 33 Then
                                                (Case
                                                  When ge.estado = 'V' Then
                                                   2605
                                                  Else
                                                   603
                                                End)
                                               When ge.cod_modalidad = 36 Then
                                                603
                                               When ge.cod_modalidad IN (31, 334) Then
                                                (Case
                                                  When (Select nvl(ah.cta_combinada, 'N')
                                                          From ah_cta_vistas ah
                                                         Where ah.nro_cuenta = v.nro_cuenta) = 'S' Then
                                                   2605
                                                  Else
                                                   2604
                                                End)
                                               When ge.cod_modalidad = 41 Then
                                                2604
                                             End),
                                             ge.cod_moneda,
                                             gc.cod_persona,
                                             to_char('1'),
                                             'C') cod_rubro,
                     mo.cod_mon_bco_central
                From (Select Distinct gb.nro_cuenta, gb.cod_causa, gb.monto
                        From pr_gar_cash   c,
                             pr_garantias  ga,
                             ge_bloqueos   gb,
                             ah_cta_vistas xx
                       Where ga.nro_garantia = c.nro_garantia
                         And ga.estado In ('C', 'V', 'N', 'T')
                         And c.nro_cta_referencia = gb.nro_cuenta
                         And gb.cod_causa = v_cod_cau_blo_garantia
                         and xx.nro_cuenta = gb.nro_cuenta
                         and xx.est_batch not in ('A', 'X', 'C')
                      union
                      Select Distinct gb.nro_cuenta, gb.cod_causa, gb.monto
                        From pr_gar_cash       c,
                             pr_garantias      ga,
                             ge_bloqueos       gb,
                             cc_cta_corrientes xx
                       Where ga.nro_garantia = c.nro_garantia
                         And ga.estado In ('C', 'V', 'N', 'T')
                         And c.nro_cta_referencia = gb.nro_cuenta
                         And gb.cod_causa = v_cod_cau_blo_garantia
                         and xx.nro_cuenta = gb.nro_cuenta
                         and xx.est_batch not in ('A', 'X', 'C')
                      union
                      Select Distinct gb.nro_cuenta, gb.cod_causa, gb.monto
                        From pr_gar_cash         c,
                             pr_garantias        ga,
                             ge_bloqueos         gb,
                             ah_cta_certificados xx
                       Where ga.nro_garantia = c.nro_garantia
                         And ga.estado In ('C', 'V', 'N', 'T')
                         And c.nro_cta_referencia = gb.nro_cuenta
                         And gb.cod_causa = v_cod_cau_blo_garantia
                         and xx.nro_cuenta = gb.nro_cuenta
                         and xx.est_batch not in ('A', 'T', 'C')) v,
                     ba_monedas mo,
                     ge_cuentas ge,
                     ge_cta_clientes gcc,
                     ge_clientes gc,
                     sb_fdg_personas sp
               Where v.nro_cuenta = ge.nro_cuenta
                 And ge.nro_cuenta = gcc.nro_cuenta
                 And gcc.relacion = 'P'
                 And gcc.cod_persona = gc.cod_persona
                 And gc.cod_persona = sp.cod_persona
                 And ge.cod_moneda = mo.cod_moneda
                 And sp.fecha = v_fec_actual) x
      Union
      -- Pignoración cta. transitoria
      Select x.nro_cuenta,
             x.certificado,
             x.cod_moneda,
             (x.capital * (-1)) capital,
             x.int_devengado,
             x.cod_tip_deudor,
             x.cod_sec_contable,
             x.residente,
             substr(x.cod_rubro, 6, 3) || '0' || substr(x.cod_rubro, 9, 2) mod_sup_rubro,
             x.cod_mon_bco_central
        From (Select v.nro_cuenta,
                     '' certificado,
                     ge.cod_moneda,
                     nvl(v.monto, 0) capital,
                     0 int_devengado,
                     gc.cod_tip_deudor,
                     gc.cod_sec_contable,
                     gc.residente,
                     fub_obt_rub_transaccion(ge.cod_modulo,
                                             ge.cod_modalidad,
                                             (Case
                                               When ge.cod_modalidad = 33 Then
                                                (Case
                                                  When ge.estado = 'V' Then
                                                   2605
                                                  Else
                                                   603
                                                End)
                                               When ge.cod_modalidad = 36 Then
                                                603
                                               When ge.cod_modalidad IN (31, 334) Then
                                                (Case
                                                  When (Select nvl(ah.cta_combinada, 'N')
                                                          From ah_cta_vistas ah
                                                         Where ah.nro_cuenta = v.nro_cuenta) = 'S' Then
                                                   2605
                                                  Else
                                                   2604
                                                End)
                                               When ge.cod_modalidad = 41 Then
                                                2604
                                             End),
                                             ge.cod_moneda,
                                             gc.cod_persona,
                                             to_char('1'),
                                             'D') cod_rubro,
                     mo.cod_mon_bco_central
                From (Select Distinct gb.nro_cuenta, gb.cod_causa, gb.monto
                        From pr_gar_cash   c,
                             pr_garantias  ga,
                             ge_bloqueos   gb,
                             ah_cta_vistas xx
                       Where ga.nro_garantia = c.nro_garantia
                         And ga.estado In ('C', 'V', 'N', 'T')
                         And c.nro_cta_referencia = gb.nro_cuenta
                         And gb.cod_causa = v_cod_cau_blo_garantia
                         and xx.nro_cuenta = gb.nro_cuenta
                         and xx.est_batch not in ('A', 'X', 'C')
                      union
                      Select Distinct gb.nro_cuenta, gb.cod_causa, gb.monto
                        From pr_gar_cash       c,
                             pr_garantias      ga,
                             ge_bloqueos       gb,
                             cc_cta_corrientes xx
                       Where ga.nro_garantia = c.nro_garantia
                         And ga.estado In ('C', 'V', 'N', 'T')
                         And c.nro_cta_referencia = gb.nro_cuenta
                         And gb.cod_causa = v_cod_cau_blo_garantia
                         and xx.nro_cuenta = gb.nro_cuenta
                         and xx.est_batch not in ('A', 'X', 'C')
                      union
                      Select Distinct gb.nro_cuenta, gb.cod_causa, gb.monto
                        From pr_gar_cash         c,
                             pr_garantias        ga,
                             ge_bloqueos         gb,
                             ah_cta_certificados xx
                       Where ga.nro_garantia = c.nro_garantia
                         And ga.estado In ('C', 'V', 'N', 'T')
                         And c.nro_cta_referencia = gb.nro_cuenta
                         And gb.cod_causa = v_cod_cau_blo_garantia
                         and xx.nro_cuenta = gb.nro_cuenta
                         and xx.est_batch not in ('A', 'T', 'C')) v,
                     ba_monedas mo,
                     ge_cuentas ge,
                     ge_cta_clientes gcc,
                     ge_clientes gc,
                     sb_fdg_personas sp
               Where v.nro_cuenta = ge.nro_cuenta
                 And ge.nro_cuenta = gcc.nro_cuenta
                 And gcc.relacion = 'P'
                 And gcc.cod_persona = gc.cod_persona
                 And gc.cod_persona = sp.cod_persona
                 And ge.cod_moneda = mo.cod_moneda
                 And sp.fecha = v_fec_actual) x
      Union
      Select x.nro_cuenta,
             x.certificado,
             x.cod_moneda,
             x.capital,
             x.int_devengado,
             x.cod_tip_deudor,
             x.cod_sec_contable,
             x.residente,
             substr(x.cod_rubro, 6, 3) || '0' || substr(x.cod_rubro, 9, 2) mod_sup_rubro,
             x.cod_mon_bco_central
        From (Select a.nro_cuenta,
                     '' certificado,
                     a.cod_moneda,
                     (nvl(sal_tot_batch, 0) - nvl(sal_ret_batch, 0) -
                     nvl(sal_blo_batch, 0)) capital,
                     0 int_devengado,
                     c.cod_tip_deudor,
                     c.cod_sec_contable,
                     c.residente,
                     a.cod_rubro,
                     mo.cod_mon_bco_central
                From ba_monedas       mo,
                     ge_clientes      c,
                     ge_cta_clientes  b,
                     cc_cta_bancarias a,
                     sb_fdg_personas  sp
               Where b.cod_persona = c.cod_persona
                 And b.nro_cuenta = a.nro_cuenta
                 And b.relacion = 'P'
                 And a.cod_modalidad = 47
                 And a.denominacion = 'CUENTA EMBARGADA'
                 And (a.sal_tot_batch <> 0 Or a.sal_ret_batch <> 0 Or
                     a.sal_blo_batch <> 0)
                 And mo.cod_moneda = a.cod_moneda
                 And c.cod_persona = sp.cod_persona
                 And sp.fecha = v_fec_actual) x
      -- embargos
      union all
      select x.nro_cuenta,
             x.certificado,
             x.cod_moneda,
             x.capital,
             x.int_devengado,
             x.cod_tip_deudor,
             x.cod_sec_contable,
             x.residente,
             substr(x.cod_rubro, 6, 3) || '0' || substr(x.cod_rubro, 9, 2) mod_sup_rubro,
             x.cod_mon_bco_central
        From (Select substr(cc.nro_cuenta || ' - EMB', 1, 20) nro_cuenta,
                     '' certificado,
                     ge.cod_moneda,
                     nvl(bl.monto, 0) capital,
                     0 int_devengado,
                     cl.cod_tip_deudor,
                     cl.cod_sec_contable,
                     cl.residente,
                     fub_obt_rub_transaccion(ge.cod_modulo,
                                             ge.cod_modalidad,
                                             855,
                                             em.cod_moneda,
                                             cc.cod_persona,
                                             '1',
                                             'C') cod_rubro,
                     mo.cod_mon_bco_central
                from ge_cuentas        ge,
                     ge_cta_clientes   cc,
                     cc_cta_corrientes ct,
                     ge_clientes       cl,
                     ge_embargos       em,
                     ge_embargos_det   ed,
                     ge_bloqueos       bl,
                     ba_monedas        mo
               where ge.nro_cuenta = cc.nro_cuenta
                 and cc.cod_persona = cl.cod_persona
                 and ed.nro_cuenta = ge.nro_cuenta
                 and em.cod_embargo = ed.cod_embargo
                 and ct.nro_cuenta = cc.nro_cuenta
                 and bl.nro_cuenta = ge.nro_cuenta
                 and bl.cod_causa = v_cod_cau_embargo
                 and bl.nro_documento = em.cod_embargo
                 and ge.cod_moneda = mo.cod_moneda
                 and em.estado = 'A'
                 and cc.relacion = 'P'
                 and ct.est_batch != 'C') x
      union all
      select x.nro_cuenta,
             x.certificado,
             x.cod_moneda,
             x.capital,
             x.int_devengado,
             x.cod_tip_deudor,
             x.cod_sec_contable,
             x.residente,
             substr(x.cod_rubro, 6, 3) || '0' || substr(x.cod_rubro, 9, 2) mod_sup_rubro,
             x.cod_mon_bco_central
        from (select substr(cc.nro_cuenta || ' - EMB', 1, 20) nro_cuenta,
                     '' certificado,
                     ge.cod_moneda,
                     nvl(bl.monto, 0) capital,
                     0 int_devengado,
                     cl.cod_tip_deudor,
                     cl.cod_sec_contable,
                     cl.residente,
                     fub_obt_rub_transaccion(ge.cod_modulo,
                                             ge.cod_modalidad,
                                             855,
                                             em.cod_moneda,
                                             cc.cod_persona,
                                             '1',
                                             'C') cod_rubro,
                     mo.cod_mon_bco_central
                from ge_cuentas      ge,
                     ge_cta_clientes cc,
                     ah_cta_vistas   ah,
                     ge_clientes     cl,
                     ge_embargos     em,
                     ge_embargos_det ed,
                     ge_bloqueos     bl,
                     ba_monedas      mo
               where ge.nro_cuenta = cc.nro_cuenta
                 and cc.cod_persona = cl.cod_persona
                 and ed.nro_cuenta = ge.nro_cuenta
                 and em.cod_embargo = ed.cod_embargo
                 and ah.nro_cuenta = cc.nro_cuenta
                 and bl.nro_cuenta = ge.nro_cuenta
                 and bl.cod_causa = v_cod_cau_embargo
                 and bl.nro_documento = em.cod_embargo
                 and ge.cod_moneda = mo.cod_moneda
                 and em.estado = 'A'
                 and cc.relacion = 'P'
                 and ah.est_batch != 'C') x;
    -- Cursor de Deudas
    Cursor c_deu Is
      Select mo.cod_mon_bco_central,
             pr.nro_cuenta,
             pr.cod_moneda,
             nvl(pr.sal_capital, 0) sal_capital,
             nvl(pr.dev_acumulado, 0) dev_acumulado
        From ba_monedas       mo,
             pr_cta_prestamos pr,
             ge_cta_clientes  cc,
             sb_fdg_personas  sp
       Where mo.cod_moneda = pr.cod_moneda
         And pr.nro_cuenta = cc.nro_cuenta
         And pr.estado != 'N'
         And cc.cod_persona = sp.cod_persona
         And sp.fecha = v_fec_actual
         And cc.relacion = 'P'
         And nvl(fup_obt_tip_afd(pr.cod_modalidad), 'N') = 'N' -- no incluir prestamos afd
         And Exists (Select '1'
                From sb_fdg_depositos sdf, ge_cta_clientes ge
               Where sdf.fecha = v_fec_actual
                 And sdf.nro_cuenta = ge.nro_cuenta
                 And ge.relacion = 'P'
                 And ge.cod_persona = sp.cod_persona)
      Union
      Select mo.cod_mon_bco_central,
             ta.nro_cuenta,
             ta.cod_moneda,
             nvl(ta.sal_facturar, 0) + nvl(ta.sal_facturado, 0) +
             nvl(ta.sal_financiado, 0) + nvl(ta.sal_cuo_pendientes, 0) saldo,
             0 devengado
        From ba_monedas      mo,
             ta_cta_tarjetas ta,
             ge_cta_clientes cc,
             sb_fdg_personas sp
       Where mo.cod_moneda = ta.cod_moneda
         And ta.nro_cuenta = cc.nro_cuenta
         And ta.estado Not In ('A', 'C')
         And nvl(ta.sal_facturar, 0) + nvl(ta.sal_facturado, 0) +
             nvl(ta.sal_financiado, 0) + nvl(ta.sal_cuo_pendientes, 0) > 0
         And cc.cod_persona = sp.cod_persona
         And sp.fecha = v_fec_actual
         And cc.relacion = 'P'
         And Exists (Select '1'
                From sb_fdg_depositos sdf, ge_cta_clientes ge
               Where sdf.fecha = v_fec_actual
                 And sdf.nro_cuenta = ge.nro_cuenta
                 And ge.relacion = 'P'
                 And ge.cod_persona = sp.cod_persona)
      Union
      Select mo.cod_mon_bco_central,
             ct.nro_cuenta,
             ct.cod_moneda,
             abs(nvl((ct.sal_tot_batch), 0) - nvl(ct.sal_blo_batch, 0) -
                 nvl(ct.sal_ret_batch, 0)) saldo,
             0 devengado
        From ba_monedas        mo,
             cc_cta_corrientes ct,
             ge_cta_clientes   cc,
             sb_fdg_personas   sp
       Where mo.cod_moneda = ct.cod_moneda
         And ct.nro_cuenta = cc.nro_cuenta
         And (nvl((ct.sal_tot_batch), 0) - nvl(ct.sal_blo_batch, 0) -
             nvl(ct.sal_ret_batch, 0)) < 0
         And ct.estado != 'C'
         And cc.cod_persona = sp.cod_persona
         And sp.fecha = v_fec_actual
         And cc.relacion = 'P'
         And Exists (Select '1'
                From sb_fdg_depositos sdf, ge_cta_clientes ge
               Where sdf.fecha = v_fec_actual
                 And sdf.nro_cuenta = ge.nro_cuenta
                 And ge.relacion = 'P'
                 And ge.cod_persona = sp.cod_persona);
    -- Cursor de Firmantes
    Cursor c_fir Is
      Select cc.cod_persona, cc.nro_cuenta, pe.tipo
        From ba_personas pe, ge_cta_clientes cc, ge_clientes ge
       Where pe.cod_persona = cc.cod_persona
         And nro_cuenta = v_nro_cuenta
         And cc.cod_persona = ge.cod_persona
         And cc.relacion != 'A'
         And cc.relacion = 'P'
       Order By decode(cc.relacion, 'P', 0, 99);
    -- Cursor de cantidad de firmantes de cuentas
    Cursor c_can_firmantes Is
      Select Trim(substr(a.nro_cuenta, 1, instr(a.nro_cuenta, '-') - 1)) nro_cuenta,
             a.rowid
        From sb_fdg_depositos a
       Where a.can_titulares < 1
         And a.fecha = v_fec_actual;
    -- Definición de Variables
    v_ref_personas      sb_fdg_datos.ref_archivo%Type;
    v_can_personas      sb_fdg_datos.can_registros%Type;
    v_ref_depositos     sb_fdg_datos.ref_archivo%Type;
    v_can_depositos     sb_fdg_datos.can_registros%Type;
    v_ref_dep_personas  sb_fdg_datos.ref_archivo%Type;
    v_can_dep_personas  sb_fdg_datos.can_registros%Type;
    v_ref_deudas        sb_fdg_datos.ref_archivo%Type;
    v_can_deudas        sb_fdg_datos.can_registros%Type;
    v_ref_deu_personas  sb_fdg_datos.ref_archivo%Type;
    v_can_deu_personas  sb_fdg_datos.can_registros%Type;
    v_ind_imp_judicial  sb_fdg_depositos.ind_imp_judicial%Type;
    v_can_titulares     sb_fdg_depositos.can_titulares%Type;
    v_capital_ext       sb_fdg_depositos.capital_ext%Type;
    v_int_devengado_ext sb_fdg_depositos.int_devengado_ext%Type;
    v_total_ext         sb_fdg_depositos.total_ext%Type;
    v_capital           sb_fdg_depositos.capital%Type;
    v_int_devengado     sb_fdg_depositos.int_devengado%Type;
    v_total             sb_fdg_depositos.total%Type;
    v_cod_mon_local     ge_par_generales.cod_mon_local%Type;
    v_cotizacion        ge_cotizaciones.val_conversion%Type;
    v_paso              Varchar2(5) := '0';
    Type tper Is Table Of c_per%Rowtype;
    tab_c_per tper := tper();
    Type tdep Is Table Of c_dep%Rowtype;
    tab_c_dep tdep := tdep();
    Type tdeu Is Table Of c_deu%Rowtype;
    tab_c_deu tdeu := tdeu();
    Function fu_es_vinculada(p_nro_cuenta In Varchar2) Return Varchar2 Is
      v_vinculada Varchar2(1) := 'N';
    Begin
      Select 'S'
        Into v_vinculada
        From ge_clientes cl, ge_cta_clientes ct
       Where cl.cod_persona = ct.cod_persona
         And ct.relacion != 'A'
         And ct.nro_cuenta = p_nro_cuenta
         And cl.cod_gru_economico = v_cod_gru_economico
         And rownum = 1;
      Return v_vinculada;
    Exception
      When no_data_found Then
        v_vinculada := 'N';
        Return v_vinculada;
    End fu_es_vinculada;

    ------------
    -- Inicio --
    ------------
  Begin
    -- Obtiene el grupo económico de la Entidad
    v_cod_gru_economico    := fug_obt_pardinamico('COD_GRU_ECO_ENTIDAD',
                                                  Null,
                                                  Null,
                                                  Null,
                                                  Null);
    v_cod_cau_embargo      := fug_obt_pardinamico('COD_CAU_BLO_EMBAR',
                                                  Null,
                                                  Null,
                                                  Null,
                                                  Null);
    v_cod_cau_blo_garantia := fug_obt_pardinamico('COD_CAU_BLO_GARAN',
                                                  Null,
                                                  Null,
                                                  Null,
                                                  Null);

    -- Obtiene la fecha actual
    v_fec_actual := pag_cal.fu_obt_fec_actual(3);
    -- Obtiene la oficina del usuario
    v_cod_oficina := fug_obt_ofi_usuario(upper(user));
    -- Obtiene la fecha anterior hábil
    v_fec_ant_habil := pag_cal.fu_obt_fec_ant_hab(v_fec_actual,
                                                  v_cod_oficina);
    -- Obtiene la moneda local
    v_cod_mon_local := pag_gen.fu_obt_mon_local;
    --
    -- Eliminar datos si ya existen para la fecha a procesar
    --
    Delete sb_fdg_dep_personas Where fecha = v_fec_actual;
    Delete sb_fdg_depositos Where fecha = v_fec_actual;
    Delete sb_fdg_deu_personas Where fecha = v_fec_actual;
    Delete sb_fdg_deudas Where fecha = v_fec_actual;
    Delete sb_fdg_personas Where fecha = v_fec_actual;
    Delete sb_fdg_datos Where fecha = v_fec_actual;
    Commit;
    v_paso := '1';
    -- Inicializa las variables
    v_ref_personas     := 'PS';
    v_ref_depositos    := 'DP';
    v_ref_dep_personas := 'PD';
    v_ref_deudas       := 'DU';
    v_ref_deu_personas := 'PU';
    v_can_personas     := 0;
    v_can_depositos    := 0;
    v_can_dep_personas := 0;
    v_can_deudas       := 0;
    v_can_deu_personas := 0;
    v_ind_imp_judicial := 0; -- Otros
    -----------------------------------------------------------------
    v_paso := '2';
    --
    -- Abre cursor Personas
    --
    Open c_per;
    Loop
      Fetch c_per Bulk Collect
        Into tab_c_per Limit 100000;
      --
      -- Inserta todas las Personas
      --
      Begin
        Forall i In 1 .. tab_c_per.count Save Exceptions
          Insert Into sb_fdg_personas Values tab_c_per (i);
      Exception
        When Others Then
          raise_application_error(-20000,
                                  'Error. Al insertar sb_fdg_personas. ' ||
                                  Sqlerrm);
      End;
      Exit When c_per%Notfound;
    End Loop;
    Close c_per;
    --
    -- Cantidad total de Personas
    --
    v_can_personas  := tab_c_per.count;
    v_can_titulares := 0;
    -----------------------------------------------------------------
    v_paso := '3';
    --
    -- Abre cursor Depósitos
    --
    Open c_dep;
    Loop
      --tab_c_dep.delete;
      Fetch c_dep Bulk Collect
        Into tab_c_dep Limit 1000;
      Exit When tab_c_dep.first Is Null;
      For i In tab_c_dep.first .. tab_c_dep.last Loop
        -- Inicializa las variables
        v_capital_ext       := 0;
        v_int_devengado_ext := 0;
        v_total_ext         := 0;
        v_capital           := 0;
        v_int_devengado     := 0;
        v_total             := 0;
        v_paso              := '3.1';
        If tab_c_dep(i).cod_moneda != v_cod_mon_local Then
          v_cotizacion        := pag_gen.fu_obt_cotizacion(tab_c_dep(i).cod_moneda,
                                                           v_fec_actual);
          v_capital_ext       := tab_c_dep(i).capital * 100;
          v_int_devengado_ext := tab_c_dep(i).int_devengado * 100;
          v_total_ext         := (nvl(v_capital_ext, 0) +
                                 nvl(v_int_devengado_ext, 0));
          v_capital           := (nvl(v_capital_ext, 0) * v_cotizacion);
          v_int_devengado     := (nvl(v_int_devengado_ext, 0) *
                                 v_cotizacion);
          v_total             := nvl(v_capital, 0) +
                                 nvl(v_int_devengado, 0);
        Else
          v_capital_ext       := 0;
          v_int_devengado_ext := 0;
          v_total_ext         := 0;
          v_capital           := tab_c_dep(i).capital * 100;
          v_int_devengado     := tab_c_dep(i).int_devengado * 100;
          v_total             := nvl(v_capital, 0) +
                                 nvl(v_int_devengado, 0);
        End If;
        --
        Begin
          Select 'S'
            Into v_insertado
            From sb_fdg_depositos
           Where fecha = v_fec_actual
             And nro_cuenta = tab_c_dep(i).nro_cuenta
             And rownum = 1;
        Exception
          When no_data_found Then
            v_insertado := 'N';
        End;
        --
        If v_insertado = 'N' Then
          v_paso          := '3.2';
          v_can_titulares := 0;
          --
          -- AP 2686 Se informan las cuentas(-)PIGNO,(-)CER, etc. en el archivo PD
          --
          If instr(tab_c_dep(i).nro_cuenta, '-') > 0 Then
            v_nro_cuenta := Trim(substr(tab_c_dep(i).nro_cuenta,
                                        1,
                                        instr(tab_c_dep(i).nro_cuenta, '-') - 1));
          Else
            v_nro_cuenta := tab_c_dep(i).nro_cuenta;
          End If;
          v_paso := '3.3';
          For r_fir In c_fir Loop
            v_can_titulares    := v_can_titulares + 1;
            v_can_dep_personas := v_can_dep_personas + 1;
            --
            -- Inserta en Personas Depósitos
            --
            Insert Into sb_fdg_dep_personas
              (cod_persona, nro_cuenta, fecha)
            Values
              (r_fir.cod_persona, tab_c_dep(i).nro_cuenta, v_fec_actual);
            If r_fir.tipo = 'J' And v_can_titulares = 1 Then
              Exit;
            End If;
          End Loop;
          --
          -- Cantidad total de Depósitos
          --
          v_can_depositos := v_can_depositos + 1;
          --
          -- Inserta en Depósitos
          --
          v_paso := '3.4';
          Insert Into sb_fdg_depositos
            (nro_cuenta,
             mod_sup_rubro,
             certificado,
             ind_imp_judicial,
             can_titulares,
             cod_mon_bco_central,
             capital_ext,
             int_devengado_ext,
             total_ext,
             capital,
             int_devengado,
             total,
             fecha)
          Values
            (tab_c_dep          (i).nro_cuenta,
             tab_c_dep          (i).mod_sup_rubro,
             tab_c_dep          (i).certificado,
             v_ind_imp_judicial,
             v_can_titulares,
             tab_c_dep          (i).cod_mon_bco_central,
             v_capital_ext,
             v_int_devengado_ext,
             v_total_ext,
             v_capital,
             v_int_devengado,
             v_total,
             v_fec_actual);
        Else
          v_paso := '3.5';
          Begin
            --
            -- Actualiza en Depósitos
            --
            Update sb_fdg_depositos a
               Set capital_ext       = nvl(capital_ext, 0) +
                                       nvl(v_capital_ext, 0),
                   int_devengado_ext = nvl(int_devengado_ext, 0) +
                                       nvl(v_int_devengado_ext, 0),
                   total_ext         = nvl(total_ext, 0) +
                                       nvl(v_total_ext, 0),
                   capital           = nvl(capital, 0) + nvl(v_capital, 0),
                   int_devengado     = nvl(int_devengado, 0) +
                                       nvl(v_int_devengado, 0),
                   total             = nvl(total, 0) + nvl(v_total, 0)
             Where fecha = v_fec_actual
               And nro_cuenta = tab_c_dep(i).nro_cuenta;
          Exception
            When Others Then
              raise_application_error(-20020,
                                      'Error en la actualización de capital' || ' ' ||
                                      Sqlerrm);
          End;
        End If;
      End Loop; --cierre del c_dep
    End Loop; --cierre del open c_dep
    Close c_dep;
    -----------------------------------------------------------------
    v_paso := '5';
    --
    -- Abre cursor Deudas
    --
    Open c_deu;
    Loop
      --tab_c_deu.delete;
      Fetch c_deu Bulk Collect
        Into tab_c_deu Limit 1000;
      Exit When tab_c_deu.first Is Null;
      For i In tab_c_deu.first .. tab_c_deu.last Loop
        --
        -- Busca las deudas de la persona
        -- Si ninguna de las personas es vinculada
        --
        If fu_es_vinculada(tab_c_deu(i).nro_cuenta) = 'N' Then
          Begin
            Select 'S'
              Into v_insertado
              From sb_fdg_deudas
             Where fecha = v_fec_actual
               And nro_cuenta = tab_c_deu(i).nro_cuenta;
          Exception
            When no_data_found Then
              v_insertado := 'N';
          End;
          If v_insertado = 'N' Then
            -- Inicializa las variables
            v_capital_ext       := 0;
            v_int_devengado_ext := 0;
            v_total_ext         := 0;
            v_capital           := 0;
            v_int_devengado     := 0;
            v_total             := 0;
            v_paso              := '5.2';
            If tab_c_deu(i).cod_moneda != v_cod_mon_local Then
              v_cotizacion        := pag_gen.fu_obt_cotizacion(tab_c_deu(i).cod_moneda,
                                                               v_fec_actual);
              v_capital_ext       := tab_c_deu(i).sal_capital;
              v_int_devengado_ext := tab_c_deu(i).dev_acumulado;
              v_total_ext         := nvl(v_capital_ext, 0) +
                                     nvl(v_int_devengado_ext, 0);
              v_capital           := nvl(v_capital_ext, 0) * v_cotizacion;
              v_int_devengado     := nvl(v_int_devengado_ext, 0) *
                                     v_cotizacion;
              v_total             := nvl(v_capital, 0) +
                                     nvl(v_int_devengado, 0);
            Else
              v_capital_ext       := 0;
              v_int_devengado_ext := 0;
              v_total_ext         := 0;
              v_capital           := tab_c_deu(i).sal_capital * 100;
              v_int_devengado     := tab_c_deu(i).dev_acumulado * 100;
              v_total             := nvl(v_capital, 0) +
                                     nvl(v_int_devengado, 0);
            End If;
            --
            v_can_titulares := 0;
            v_nro_cuenta    := tab_c_deu(i).nro_cuenta;
            v_paso          := '5.3';
            For r_fir In c_fir Loop
              v_can_titulares    := v_can_titulares + 1;
              v_can_deu_personas := v_can_deu_personas + 1;
              --
              -- Inserta en Personas Deudas
              --
              Insert Into sb_fdg_deu_personas
                (cod_persona, nro_cuenta, fecha)
              Values
                (r_fir.cod_persona, r_fir.nro_cuenta, v_fec_actual);
            End Loop;
            --
            -- Cantidad total de Deudas
            --
            v_can_deudas := v_can_deudas + 1;
            --
            -- Inserta en Deudas
            --
            v_paso := '5.4';
            Insert Into sb_fdg_deudas
              (nro_cuenta,
               can_titulares,
               cod_mon_bco_central,
               capital_ext,
               int_devengado_ext,
               total_ext,
               capital,
               int_devengado,
               total,
               fecha)
            Values
              (tab_c_deu(i).nro_cuenta,
               v_can_titulares,
               tab_c_deu(i).cod_mon_bco_central,
               v_capital_ext,
               nvl(v_int_devengado_ext, 0),
               v_total_ext,
               v_capital,
               nvl(v_int_devengado, 0),
               v_total,
               v_fec_actual);
          End If;
        End If;
      End Loop; --cierre del c_deu
    End Loop; --cierre del open c_deu
    Close c_deu;
    -----------------------------------------------------------------
    v_paso := '6';
    --
    -- Elimina los Registros con Total 0
    --
    Delete sb_fdg_depositos f
     Where f.total = 0
       And f.fecha = v_fec_actual;
    Delete sb_fdg_dep_personas f
     Where Not Exists (Select 1
              From sb_fdg_depositos sd
             Where sd.nro_cuenta = f.nro_cuenta
               And sd.fecha = v_fec_actual)
       And f.fecha = v_fec_actual;
    Delete sb_fdg_deudas d
     Where d.total = 0
       And d.fecha = v_fec_actual;
    Delete sb_fdg_deu_personas d
     Where Not Exists (Select 1
              From sb_fdg_deudas sd
             Where sd.nro_cuenta = d.nro_cuenta
               And sd.fecha = v_fec_actual)
       And d.fecha = v_fec_actual;
    --
    -- Actualiza la cantidad de firmantes de las cuentas de pignoración
    --
    v_paso := '7';
    For reg In c_can_firmantes Loop
      v_can_titulares := 0;
      v_nro_cuenta    := reg.nro_cuenta;
      For r_fir In c_fir Loop
        v_can_titulares := v_can_titulares + 1;
        If r_fir.tipo = 'J' And v_can_titulares = 1 Then
          Exit;
        End If;
      End Loop;
      --
      -- Actualizo la tabla de depósitos
      --
      Update sb_fdg_depositos sd
         Set sd.can_titulares = v_can_titulares
       Where sd.rowid = reg.rowid;
    End Loop; --cierre cursor firmantes
    --
    -- Inserta en Datos
    --
    v_paso := '8';
    --personas
    Insert Into sb_fdg_datos
      (ref_archivo, can_registros, fecha)
    Values
      (v_ref_personas, v_can_personas, v_fec_actual);
    --depósits
    Insert Into sb_fdg_datos
      (ref_archivo, can_registros, fecha)
    Values
      (v_ref_depositos, v_can_depositos, v_fec_actual);
    --personas depósitos
    Insert Into sb_fdg_datos
      (ref_archivo, can_registros, fecha)
    Values
      (v_ref_dep_personas, v_can_dep_personas, v_fec_actual);
    --deudas
    Insert Into sb_fdg_datos
      (ref_archivo, can_registros, fecha)
    Values
      (v_ref_deudas, v_can_deudas, v_fec_actual);
    --personas deudas
    Insert Into sb_fdg_datos
      (ref_archivo, can_registros, fecha)
    Values
      (v_ref_deu_personas, v_can_deu_personas, v_fec_actual);
    --
    -- Actualiza el parámetro que indica la fecha de ejecución
    --
    v_paso := '9';
    Update ge_par_dinamicos a
       Set a.val_parametro = to_char(v_fec_actual, 'DD/MM/YYYY')
     Where a.parametro = 'FEC_PRO_FDG';
  Exception
    When Others Then
      If Sqlcode <= '-20000' Then
        Raise;
      Else
        raise_application_error(-20000,
                                'En pr_fon_garantia. Paso: ' || v_paso || ' ' ||
                                Sqlerrm);
      End If;
  End pr_fon_garantia;
  /* Obtener devengado_his total de CDA. */
  FUNCTION FU_OBT_DEV_CDA_HIS(P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE,
                              P_ANO        IN AH_SAL_MENSUALES.ANO%TYPE,
                              P_MES        IN AH_SAL_MENSUALES.MES%TYPE)
    RETURN NUMBER IS
    v_devengado ah_devengados_his.mto_interes%type;
  BEGIN
    select SUM(nvl(d.mto_interes, 0)) -- round(nvl(pag_gen.fu_cal_int_simple(p_capital, p_fec_calculo-p_fec_apertura, d.val_tasa),0),0)
      into v_devengado
      from ah_devengados_his d
     where d.nro_cuenta = p_nro_cuenta
       and d.ano = p_ano
       and d.mes = p_mes;
    return nvl(v_devengado, 0);
  END;

  PROCEDURE PR_GEN_ENCAJES_DET(P_FEC_ACTUAL IN date) IS

    --Cursor para cuentas en MONEDA LOCAL
    cursor ctas_ml is
    --CDAs con cupones vencidos, VISTA, SUJETO AL 18%
      select ah.nro_cuenta,
             ah.cod_modulo,
             ah.cod_modalidad,
             ah.cod_moneda,
             decode(ah.est_cer_batch,
                    'V',
                    nvl(ah.sal_tot_batch, 0) - nvl(ah.sal_ret_batch, 0),
                    'P',
                    nvl(ah.sal_tot_batch, 0) - nvl(ah.sal_ret_batch, 0),
                    nvl(ah.sal_tot_batch, 0) - nvl(ah.capital, 0) -
                    nvl(ah.sal_ret_batch, 0)) as monto,
             'V' as tipo,
             15 as sujeto_a
        from ah_cta_certificados ah
       where --ah.est_batch NOT IN ('C','T')
       ah.est_batch NOT IN ('C', 'T', 'X', 'A')
       and (est_cer_batch in ('V', 'P') or sal_tot_batch > capital)
       and cod_moneda = pag_gen.fu_obt_mon_local
       and cod_modalidad = 33
      union
      --CAJAS DE AHORRO, VISTA, SUJETO AL 18%
      select ah.nro_cuenta,
             ah.cod_modulo,
             ah.cod_modalidad,
             ah.cod_moneda,
             nvl(sal_tot_batch, 0) - nvl(ah.sal_ret_batch, 0) as monto,
             'V' as tipo,
             15 as sujeto_a
        from ah_cta_vistas ah
       where cod_moneda = pag_gen.fu_obt_mon_local
         and (ah.sal_tot_batch <> 0 or ah.sal_ret_batch <> 0 or
             ah.sal_blo_batch <> 0)
      union
      --CUENTA CORRIENTES, VISTA, SUJETO AL 18%
      select cc.nro_cuenta,
             cc.cod_modulo,
             cc.cod_modalidad,
             cc.cod_moneda,
             nvl(cc.sal_tot_batch, 0) - nvl(cc.sal_ret_batch, 0) -
             nvl(cc.sal_blo_batch, 0) as monto,
             'V' as tipo,
             15 as sujeto_a
        from cc_cta_corrientes cc
       where cod_moneda = pag_gen.fu_obt_mon_local
         AND (NVL(cc.SAL_TOT_BATCH, 0) <> 0 OR
             NVL(cc.SAL_RET_BATCH, 0) <> 0 OR
             NVL(cc.SAL_BLO_BATCH, 0) <> 0)
         and (nvl(cc.sal_tot_batch, 0) - nvl(cc.sal_ret_batch, 0) -
             nvl(cc.sal_blo_batch, 0)) > 0
         and nvl(cc.sal_blo_batch, 0) = 0
      union
      select cc.nro_cuenta,
             cc.cod_modulo,
             cc.cod_modalidad,
             cc.cod_moneda,
             nvl(cc.sal_tot_batch, 0) - nvl(cc.sal_ret_batch, 0) as monto,
             'V' as tipo,
             15 as sujeto_a
        from cc_cta_corrientes cc
       where cod_moneda = pag_gen.fu_obt_mon_local
         AND (NVL(cc.SAL_TOT_BATCH, 0) <> 0 OR
             NVL(cc.SAL_RET_BATCH, 0) <> 0 OR
             NVL(cc.SAL_BLO_BATCH, 0) <> 0)
         and (nvl(cc.sal_tot_batch, 0) - nvl(cc.sal_ret_batch, 0) -
             nvl(cc.sal_blo_batch, 0)) > 0
         and nvl(cc.sal_blo_batch, 0) > 0
      union
      select cc.nro_cuenta,
             cc.cod_modulo,
             cc.cod_modalidad,
             cc.cod_moneda,
             nvl(cc.sal_blo_batch, 0) as monto,
             'V' as tipo,
             15 as sujeto_a
        from cc_cta_corrientes cc
       where cod_moneda = pag_gen.fu_obt_mon_local
         AND (NVL(cc.SAL_TOT_BATCH, 0) <> 0 OR
             NVL(cc.SAL_RET_BATCH, 0) <> 0 OR
             NVL(cc.SAL_BLO_BATCH, 0) <> 0)
         and (nvl(cc.sal_tot_batch, 0) - nvl(cc.sal_ret_batch, 0) -
             nvl(cc.sal_blo_batch, 0)) <= 0
         and nvl(cc.sal_blo_batch, 0) > 0
      union
      --CDAs, PLAZO, SUJETO AL 18%
      select ah.nro_cuenta,
             ah.cod_modulo,
             ah.cod_modalidad,
             ah.cod_moneda,
             nvl(ah.capital, 0) as monto,
             'P' as tipo,
             15 as sujeto_a
        from ah_cta_certificados ah
       where fec_vencimiento - fec_apertura between 2 and 180
         and est_cer_batch not in ('V', 'P')
            --and ah.est_batch NOT IN ('C','T')
         and ah.est_batch NOT IN ('C', 'T', 'X', 'A')
         and cod_moneda = pag_gen.fu_obt_mon_local
         and 'N' =
             nvl(fug_obt_paradicional(ah.nro_cuenta, 'EXO_ENCAJES'), 'N')
         and cod_modalidad = 33
      union
      select ah.nro_cuenta,
             ah.cod_modulo,
             ah.cod_modalidad,
             ah.cod_moneda,
             nvl(ah.capital, 0) as monto,
             'P' as tipo,
             15 as sujeto_a
        from ah_cta_certificados ah
       where fec_vencimiento - fec_apertura between 181 and 360
         and est_cer_batch not in ('V', 'P')
            --and ah.est_batch NOT IN ('C','T')
         and ah.est_batch NOT IN ('C', 'T', 'X', 'A')
         and cod_moneda = pag_gen.fu_obt_mon_local
         and 'N' =
             nvl(fug_obt_paradicional(ah.nro_cuenta, 'EXO_ENCAJES'), 'N')
         and cod_modalidad = 33
      union
      --CDAs, PLAZO, SUJETO AL 0%
      select ah.nro_cuenta,
             ah.cod_modulo,
             ah.cod_modalidad,
             ah.cod_moneda,
             nvl(ah.capital, 0) as monto,
             'P' as tipo,
             0 as sujeto_a
        from ah_cta_certificados ah
       where fec_vencimiento - fec_apertura between 361 and 540
         and est_cer_batch not in ('V', 'P')
            --and ah.est_batch NOT IN ('C','T')
         and ah.est_batch NOT IN ('C', 'T', 'X', 'A')
         and cod_moneda = pag_gen.fu_obt_mon_local
         and 'N' =
             nvl(fug_obt_paradicional(ah.nro_cuenta, 'EXO_ENCAJES'), 'N')
         and cod_modalidad = 33
      union
      select ah.nro_cuenta,
             ah.cod_modulo,
             ah.cod_modalidad,
             ah.cod_moneda,
             nvl(ah.capital, 0) as monto,
             'P' as tipo,
             0 as sujeto_a
        from ah_cta_certificados ah
       where fec_vencimiento - fec_apertura between 541 and 1080
         and est_cer_batch not in ('V', 'P')
            --and ah.est_batch NOT IN ('C','T')
         and ah.est_batch NOT IN ('C', 'T', 'X', 'A')
         and cod_moneda = pag_gen.fu_obt_mon_local
         and 'N' =
             nvl(fug_obt_paradicional(ah.nro_cuenta, 'EXO_ENCAJES'), 'N')
         and cod_modalidad = 33
      union
      select ah.nro_cuenta,
             ah.cod_modulo,
             ah.cod_modalidad,
             ah.cod_moneda,
             nvl(ah.capital, 0) as monto,
             'P' as tipo,
             0 as sujeto_a
        from ah_cta_certificados ah
       where fec_vencimiento - fec_apertura >= 1081
         and est_cer_batch not in ('V', 'P')
            --and ah.est_batch NOT IN ('C','T')
         and ah.est_batch NOT IN ('C', 'T', 'X', 'A')
         and cod_moneda = pag_gen.fu_obt_mon_local
         and 'N' =
             nvl(fug_obt_paradicional(ah.nro_cuenta, 'EXO_ENCAJES'), 'N')
         and cod_modalidad = 33;

    cursor monedas is
      select distinct (cod_moneda) cod_moneda
        from ge_cuentas
       where cod_moneda <> pag_gen.fu_obt_mon_local
         and cod_modulo in (3, 4)
         and cod_modalidad not in (43, 45);

    --Cursor para cuentas en MONEDA EXTRANJERA
    cursor ctas_me(p_reg in varchar2) is
    --CDAs, VISTA, SUJETO AL 25%
      select ah.nro_cuenta,
             ah.cod_modulo,
             ah.cod_modalidad,
             ah.cod_moneda,
             decode(ah.est_cer_batch,
                    'V',
                    nvl(ah.sal_tot_batch, 0) - nvl(ah.sal_ret_batch, 0),
                    'P',
                    nvl(ah.sal_tot_batch, 0) - nvl(ah.sal_ret_batch, 0),
                    nvl(ah.sal_tot_batch, 0) - nvl(ah.capital, 0) -
                    nvl(ah.sal_ret_batch, 0)) as monto,
             'V' as tipo,
             21 as sujeto_a
        from ah_cta_certificados ah
       where --ah.est_batch NOT IN ('C','T')
       ah.est_batch NOT IN ('C', 'T', 'X', 'A')
       and (est_cer_batch IN ('V', 'P') or sal_tot_batch > capital)
       and nvl(ah.sal_ret_batch, 0) = 0
       and cod_moneda = p_reg
       and cod_modalidad = 33
      union
      --CDAs, PLAZO, SUJETO AL 25%
      select ah.nro_cuenta,
             ah.cod_modulo,
             ah.cod_modalidad,
             ah.cod_moneda,
             nvl(ah.capital, 0) as monto,
             'P' as tipo,
             21 as sujeto_a
        from ah_cta_certificados ah
       where fec_vencimiento - fec_apertura between 2 and 360
            --and ah.est_batch NOT IN ('C','T')
         and ah.est_batch NOT IN ('C', 'T', 'X', 'A')
         and est_cer_batch not in ('V', 'P')
         and cod_moneda = p_reg
         and cod_modalidad = 33
      union
      --CAJAS DE AHORRO, VISTA, SUJETO AL 25%
      select ah.nro_cuenta,
             ah.cod_modulo,
             ah.cod_modalidad,
             ah.cod_moneda,
             nvl(ah.sal_tot_batch, 0) - nvl(ah.sal_ret_batch, 0) as monto,
             'V' as tipo,
             21 as sujeto_a
        from ah_cta_vistas ah
       where cod_moneda = p_reg
         and (ah.sal_tot_batch <> 0 or ah.sal_ret_batch <> 0 or
             ah.sal_blo_batch <> 0)
      union
      --CUENTAS CORRIENTES, VISTA, SUJETO AL 25%
      select cc.nro_cuenta,
             cc.cod_modulo,
             cc.cod_modalidad,
             cc.cod_moneda,
             nvl(cc.sal_tot_batch, 0) - nvl(cc.sal_ret_batch, 0) -
             nvl(cc.sal_blo_batch, 0) as monto,
             'V' as tipo,
             21 as sujeto_a
        from cc_cta_corrientes cc
       where cod_moneda = p_reg
         AND (NVL(cc.SAL_TOT_BATCH, 0) <> 0 OR
             NVL(cc.SAL_RET_BATCH, 0) <> 0 OR
             NVL(cc.SAL_BLO_BATCH, 0) <> 0)
         and (nvl(cc.sal_tot_batch, 0) - nvl(cc.sal_ret_batch, 0) -
             nvl(cc.sal_blo_batch, 0)) > 0
         and nvl(cc.sal_blo_batch, 0) = 0
      union
      select cc.nro_cuenta,
             cc.cod_modulo,
             cc.cod_modalidad,
             cc.cod_moneda,
             nvl(cc.sal_tot_batch, 0) - nvl(cc.sal_ret_batch, 0),
             'V' as tipo,
             21 as sujeto_a
        from cc_cta_corrientes cc
       where cod_moneda = p_reg
         AND (NVL(cc.SAL_TOT_BATCH, 0) <> 0 OR
             NVL(cc.SAL_RET_BATCH, 0) <> 0 OR
             NVL(cc.SAL_BLO_BATCH, 0) <> 0)
         and (nvl(cc.sal_tot_batch, 0) - nvl(cc.sal_ret_batch, 0) -
             nvl(cc.sal_blo_batch, 0)) > 0
         and nvl(cc.sal_blo_batch, 0) > 0
      union
      select cc.nro_cuenta,
             cc.cod_modulo,
             cc.cod_modalidad,
             cc.cod_moneda,
             nvl(cc.sal_blo_batch, 0) as monto,
             'V' as tipo,
             21 as sujeto_a
        from cc_cta_corrientes cc
       where cod_moneda = p_reg
         AND (NVL(cc.SAL_TOT_BATCH, 0) <> 0 OR
             NVL(cc.SAL_RET_BATCH, 0) <> 0 OR
             NVL(cc.SAL_BLO_BATCH, 0) <> 0)
         and (nvl(cc.sal_tot_batch, 0) - nvl(cc.sal_ret_batch, 0) -
             nvl(cc.sal_blo_batch, 0)) <= 0
         and nvl(cc.sal_blo_batch, 0) > 0
      union
      --CDAs, PLAZO, SUJETO AL 16,5%
      select ah.nro_cuenta,
             ah.cod_modulo,
             ah.cod_modalidad,
             ah.cod_moneda,
             nvl(capital, 0) as monto,
             'P' as tipo,
             16.5 as sujeto_a
        from ah_cta_certificados ah
       where fec_vencimiento - fec_apertura between 361 and 540
         and est_cer_batch not in ('V', 'P')
            --and ah.est_batch NOT IN ('C','T')
         and ah.est_batch NOT IN ('C', 'T', 'X', 'A')
         and cod_moneda = p_reg
         and 'N' =
             nvl(fug_obt_paradicional(ah.nro_cuenta, 'EXO_ENCAJES'), 'N')
         and cod_modalidad = 33
      union
      --CDAs, PLAZO, SUJETO AL 0%
      select ah.nro_cuenta,
             ah.cod_modulo,
             ah.cod_modalidad,
             ah.cod_moneda,
             nvl(capital, 0) as monto,
             'P' as tipo,
             0 as sujeto_a
        from ah_cta_certificados ah
       where fec_vencimiento - fec_apertura between 541 and 1080
         and est_cer_batch not in ('V', 'P')
            --and ah.est_batch NOT IN ('C','T')
         and ah.est_batch NOT IN ('C', 'T', 'X', 'A')
         and cod_moneda = p_reg
         and 'N' =
             nvl(fug_obt_paradicional(ah.nro_cuenta, 'EXO_ENCAJES'), 'N')
         and cod_modalidad = 33
      union
      --CDAs, PLAZO, SUJETO AL 0%
      select ah.nro_cuenta,
             ah.cod_modulo,
             ah.cod_modalidad,
             ah.cod_moneda,
             nvl(capital, 0) as monto,
             'P' as tipo,
             0 as sujeto_a
        from ah_cta_certificados ah
       where fec_vencimiento - fec_apertura >= 1081
         and est_cer_batch not in ('V', 'P')
            --and ah.est_batch NOT IN ('C','T')
         and ah.est_batch NOT IN ('C', 'T', 'X', 'A')
         and cod_moneda = p_reg
         and 'N' =
             nvl(fug_obt_paradicional(ah.nro_cuenta, 'EXO_ENCAJES'), 'N')
         and cod_modalidad = 33;

  BEGIN

    for x in ctas_ml loop
      insert into sb_encajes_det
        (fecha,
         nro_cuenta,
         cod_modulo,
         cod_modalidad,
         cod_moneda,
         monto,
         tipo,
         sujeto_a)
      values
        (p_fec_actual,
         x.nro_cuenta,
         x.cod_modulo,
         x.cod_modalidad,
         x.cod_moneda,
         x.monto,
         x.tipo,
         x.sujeto_a);
    end loop;

    for reg in monedas loop
      for y in ctas_me(reg.cod_moneda) loop
        insert into sb_encajes_det
          (fecha,
           nro_cuenta,
           cod_modulo,
           cod_modalidad,
           cod_moneda,
           monto,
           tipo,
           sujeto_a)
        values
          (p_fec_actual,
           y.nro_cuenta,
           y.cod_modulo,
           y.cod_modalidad,
           y.cod_moneda,
           y.monto,
           y.tipo,
           y.sujeto_a);
      end loop;
    end loop;

  EXCEPTION
    WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20000, SQLERRM || ' SB_ENCAJES_DET');
  END;
  --
  PROCEDURE PR_GEN_ENC_ASCII_HIS(P_FECHA IN DATE default null) IS

    v_fec_proceso   date;
    v_fec_contable  date;
    v_can_datos     number(4) default 0;
    v_per_entidad   ge_par_generales.cod_persona%type := fug_obt_per_entidad;
    v_cod_mon_local ba_monedas.cod_moneda%type;
    ---
    v_sal_cap_cov_pyg number(18, 2);
    v_cantidad_pyg    number;
    v_sal_cap_cov_usd number(18, 2);
    v_cantidad_usd    number;
    ---
    cursor c_res_254 is
      select v.moneda,
             v.cuentas,
             v.sub_cuenta,
             v.plazo,
             (Case
               when sum(v.monto) <= v_rango1 then
                '1'
               when sum(v.monto) > v_rango1 and sum(v.monto) <= v_rango2 then
                '2'
               when sum(v.monto) > v_rango2 and sum(v.monto) <= v_rango3 then
                '3'
               when sum(v.monto) > v_rango3 and sum(v.monto) <= v_rango4 then
                '4'
               when sum(v.monto) > v_rango4 and sum(v.monto) <= v_rango5 then
                '5'
               when sum(v.monto) >= v_rango6 then
                '6'
             end) rango,
             count(v.monto) cantidad,
             sum(nvl(v.monto, 0)) monto,
             sum(nvl(v.mto_cta, 0)) mto_cta,
             v.cod_departamento depto,
             v.exonera
        from (select m.cod_mon_bco_central moneda,
                     substr(c.cod_rubro, 6, 3) cuentas,
                     substr(c.cod_rubro, 9, 2) sub_cuenta,
                     '10' plazo,
                     fub_con_mon_a_moneda(c.cod_moneda,
                                          v_cod_mon_local,
                                          d.sal_actual,
                                          null,
                                          c.fecha) monto,
                     d.sal_actual mto_cta,
                     d.nro_cuenta cuenta,
                     decode(nvl(fug_obt_paradicional(d.nro_cuenta,
                                                     'EXO_ENCAJES'),
                                'N'),
                            'N',
                            0,
                            1) exonera,
                     c.tip_saldo,
                     nvl(g.cod_departamento, 1) cod_departamento
                from cb_sal_inventarios_det_his d,
                     cb_sal_inventarios_his     c,
                     ba_monedas                 m,
                     ge_clientes                g,
                     ge_cta_clientes            ge
               where d.nro_referencia = c.nro_referencia
                 and c.cod_moneda = m.cod_moneda
                 and c.cod_modulo = 3
                 and c.cod_modalidad IN (31, 334)
                 and c.tip_saldo in ('C', 'P', 'T', 'Q')
                 and ge.nro_cuenta = d.nro_cuenta
                 and g.cod_persona = ge.cod_persona
                 and ge.relacion = 'P'
                 and nvl(c.sal_total, 0) != 0
                 and c.cod_rubro is not null
                 and d.fecha = c.fecha
                 and c.fecha = v_fec_proceso) v,
             ah_cta_vistas a
       where v.cuenta = a.nro_cuenta
       group by v.moneda,
                v.cuentas,
                v.sub_cuenta,
                v.plazo,
                v.exonera,
                v.cod_departamento
      union all
      select v.moneda,
             v.cuentas,
             v.sub_cuenta,
             v.plazo,
             (Case
               when sum(v.monto) <= v_rango1 then
                '1'
               when sum(v.monto) > v_rango1 and sum(v.monto) <= v_rango2 then
                '2'
               when sum(v.monto) > v_rango2 and sum(v.monto) <= v_rango3 then
                '3'
               when sum(v.monto) > v_rango3 and sum(v.monto) <= v_rango4 then
                '4'
               when sum(v.monto) > v_rango4 and sum(v.monto) <= v_rango5 then
                '5'
               when sum(v.monto) >= v_rango6 then
                '6'
             end) rango,
             count(v.monto) cantidad,
             sum(nvl(v.monto, 0)) monto,
             sum(nvl(v.mto_cta, 0)) mto_cta,
             v.cod_departamento depto,
             v.exonera
        from (select m.cod_mon_bco_central moneda,
                     substr(c.cod_rubro, 6, 3) cuentas,
                     substr(c.cod_rubro, 9, 2) sub_cuenta,
                     '10' plazo,
                     fub_con_mon_a_moneda(c.cod_moneda,
                                          v_cod_mon_local,
                                          d.sal_actual,
                                          null,
                                          c.fecha) monto,
                     d.sal_actual mto_cta,
                     d.nro_cuenta cuenta,
                     decode(nvl(fug_obt_paradicional(d.nro_cuenta,
                                                     'EXO_ENCAJES'),
                                'N'),
                            'N',
                            0,
                            1) exonera,
                     c.tip_saldo,
                     nvl(g.cod_departamento, 1) cod_departamento
                from cb_sal_inventarios_det_his d,
                     cb_sal_inventarios_his     c,
                     ba_monedas                 m,
                     ge_clientes                g,
                     ge_cta_clientes            ge
               where d.nro_referencia = c.nro_referencia
                 and c.cod_moneda = m.cod_moneda
                 and c.cod_modulo = 4
                 and c.cod_modalidad = 41
                 and c.tip_saldo in ('C', 'P', 'T')
                 and c.situacion = 'N'
                 and ge.nro_cuenta = d.nro_cuenta
                 and g.cod_persona = ge.cod_persona
                 and ge.relacion = 'P'
                 and nvl(c.sal_total, 0) != 0
                 and c.cod_rubro is not null
                 and d.fecha = c.fecha
                 and c.fecha = v_fec_proceso) v,
             cc_cta_corrientes a
       where v.cuenta = a.nro_cuenta
       group by v.moneda,
                v.cuentas,
                v.sub_cuenta,
                v.plazo,
                v.exonera,
                v.cod_departamento
      union all
      select v.moneda,
             v.cuentas,
             v.sub_cuenta,
             v.plazo,
             (Case
               when sum(v.monto) <= v_rango1 then
                '1'
               when sum(v.monto) > v_rango1 and sum(v.monto) <= v_rango2 then
                '2'
               when sum(v.monto) > v_rango2 and sum(v.monto) <= v_rango3 then
                '3'
               when sum(v.monto) > v_rango3 and sum(v.monto) <= v_rango4 then
                '4'
               when sum(v.monto) > v_rango4 and sum(v.monto) <= v_rango5 then
                '5'
               when sum(v.monto) >= v_rango6 then
                '6'
             end) rango,
             count(v.monto) cantidad,
             sum(nvl(v.monto, 0)) monto,
             sum(nvl(v.mto_cta, 0)) mto_cta,
             v.cod_departamento depto,
             v.exonera
        from (select m.cod_mon_bco_central moneda,
                     substr(c.cod_rubro, 6, 3) cuentas,
                     substr(c.cod_rubro, 9, 2) sub_cuenta,
                     '10' plazo,
                     fub_con_mon_a_moneda(c.cod_moneda,
                                          v_cod_mon_local,
                                          d.sal_actual,
                                          null,
                                          c.fecha) monto,
                     d.sal_actual mto_cta,
                     d.nro_cuenta cuenta,
                     decode(nvl(fug_obt_paradicional(d.nro_cuenta,
                                                     'EXO_ENCAJES'),
                                'N'),
                            'N',
                            0,
                            1) exonera,
                     c.tip_saldo,
                     nvl(g.cod_departamento, 1) cod_departamento
                from cb_sal_inventarios_det_his d,
                     cb_sal_inventarios_his     c,
                     ba_monedas                 m,
                     ge_clientes                g,
                     ge_cta_clientes            ge
               where d.nro_referencia = c.nro_referencia
                 and c.cod_moneda = m.cod_moneda
                 and c.cod_modulo = 4
                 and c.cod_modalidad = 41
                 and c.tip_saldo = 'Q'
                 and ge.nro_cuenta = d.nro_cuenta
                 and g.cod_persona = ge.cod_persona
                 and ge.relacion = 'P'
                 and nvl(c.sal_total, 0) != 0
                 and c.cod_rubro is not null
                 and d.fecha = c.fecha
                 and c.fecha = v_fec_proceso) v,
             cc_cta_corrientes a
       where v.cuenta = a.nro_cuenta
       group by v.moneda,
                v.cuentas,
                v.sub_cuenta,
                v.plazo,
                v.exonera,
                v.cod_departamento
      union all
      --Cheque Certificado.
      select v.moneda,
             v.cuentas,
             v.sub_cuenta,
             v.plazo,
             (Case
               when sum(v.monto) <= v_rango1 then
                '1'
               when sum(v.monto) > v_rango1 and sum(v.monto) <= v_rango2 then
                '2'
               when sum(v.monto) > v_rango2 and sum(v.monto) <= v_rango3 then
                '3'
               when sum(v.monto) > v_rango3 and sum(v.monto) <= v_rango4 then
                '4'
               when sum(v.monto) > v_rango4 and sum(v.monto) <= v_rango5 then
                '5'
               when sum(v.monto) >= v_rango6 then
                '6'
             end) rango,
             count(v.monto) cantidad,
             sum(nvl(v.monto, 0)) monto,
             sum(nvl(v.mto_cta, 0)) mto_cta,
             v.cod_departamento depto,
             v.exonera
        from (select m.cod_mon_bco_central moneda,
                     substr(c.cod_rubro, 6, 3) cuentas,
                     substr(c.cod_rubro, 9, 2) sub_cuenta,
                     '10' plazo,
                     fub_con_mon_a_moneda(c.cod_moneda,
                                          v_cod_mon_local,
                                          d.sal_actual,
                                          null,
                                          c.fecha) monto,
                     d.sal_actual mto_cta,
                     d.nro_cuenta cuenta,
                     decode(nvl(fug_obt_paradicional(d.nro_cuenta,
                                                     'EXO_ENCAJES'),
                                'N'),
                            'N',
                            0,
                            1) exonera,
                     c.tip_saldo,
                     nvl(g.cod_departamento, 1) cod_departamento
                from cb_sal_inventarios_det_his d,
                     cb_sal_inventarios_his     c,
                     ba_monedas                 m,
                     ge_clientes                g,
                     ge_cta_clientes            ge
               where d.nro_referencia = c.nro_referencia
                 and c.cod_moneda = m.cod_moneda
                 and c.cod_modulo = 4
                 and c.cod_modalidad = 41
                 and c.tip_saldo = 'C'
                 and c.situacion is null
                 and ge.nro_cuenta = d.nro_cuenta
                 and g.cod_persona = ge.cod_persona
                 and ge.relacion = 'P'
                 and nvl(c.sal_total, 0) != 0
                 and c.cod_rubro is not null
                 and d.fecha = c.fecha
                 and c.fecha = v_fec_proceso) v,
             cc_cta_corrientes a
       where v.cuenta = a.nro_cuenta
         and exists
       (select 1
                from cc_che_certificados ch, cc_cta_bancarias cb
               where ch.nro_cuenta = a.nro_cuenta
                 and ch.nro_cta_certificado = cb.nro_cuenta)
       group by v.moneda,
                v.cuentas,
                v.sub_cuenta,
                v.plazo,
                v.exonera,
                v.cod_departamento
      union all
      -- C.D.A. en estado Normal.
      select v.moneda,
             v.cuentas,
             v.sub_cuenta,
             (case
               when fec_vencimiento - fec_apertura between 1 and 30 then
                '20'
               when fec_vencimiento - fec_apertura between 31 and 60 then
                '30'
               when fec_vencimiento - fec_apertura between 61 and 90 then
                '40'
               when fec_vencimiento - fec_apertura between 91 and 180 then
                '50'
               when fec_vencimiento - fec_apertura between 181 and 360 then
                '60'
               when fec_vencimiento - fec_apertura between 361 and 540 then
                '71'
               when fec_vencimiento - fec_apertura between 541 and 1080 then
                '73'
               when fec_vencimiento - fec_apertura > 1080 then
                '80'
               else
                '10'
             end) plazo,
             (Case
               when sum(v.monto) <= v_rango1 then
                '1'
               when sum(v.monto) > v_rango1 and sum(v.monto) <= v_rango2 then
                '2'
               when sum(v.monto) > v_rango2 and sum(v.monto) <= v_rango3 then
                '3'
               when sum(v.monto) > v_rango3 and sum(v.monto) <= v_rango4 then
                '4'
               when sum(v.monto) > v_rango4 and sum(v.monto) <= v_rango5 then
                '5'
               when sum(v.monto) >= v_rango6 then
                '6'
             end) rango,
             count(v.monto) cantidad,
             sum(nvl(v.monto, 0)),
             sum(nvl(v.mto_cta, 0)) mto_cta,
             v.cod_departamento,
             v.exonera
        from (select m.cod_mon_bco_central moneda,
                     substr(c.cod_rubro, 6, 3) cuentas,
                     substr(c.cod_rubro, 9, 2) sub_cuenta,
                     fub_con_mon_a_moneda(c.cod_moneda,
                                          v_cod_mon_local,
                                          d.sal_actual,
                                          null,
                                          c.fecha) monto,
                     d.sal_actual mto_cta,
                     d.nro_cuenta cuenta,
                     decode(nvl(fug_obt_paradicional(d.nro_cuenta,
                                                     'EXO_ENCAJES'),
                                'N'),
                            'N',
                            0,
                            1) exonera,
                     c.tip_saldo,
                     nvl(g.cod_departamento, 1) cod_departamento
                from cb_sal_inventarios_det_his d,
                     cb_sal_inventarios_his     c,
                     ba_monedas                 m,
                     ge_clientes                g,
                     ge_cta_clientes            ge
               where d.nro_referencia = c.nro_referencia
                 and c.cod_moneda = m.cod_moneda
                 and c.cod_modulo = 3
                 and c.cod_modalidad not in (31, 36, 334)
                 and c.tip_saldo in ('C', 'P', 'T')
                 and c.situacion = 'N'
                 and ge.nro_cuenta = d.nro_cuenta
                 and g.cod_persona = ge.cod_persona
                 and ge.relacion = 'P'
                 and nvl(c.sal_total, 0) != 0
                 and c.cod_rubro is not null
                 and d.fecha = c.fecha
                 and c.fecha = v_fec_proceso) v,
             ah_cta_certificados a
       where v.cuenta = a.nro_cuenta
       group by v.moneda,
                v.cuentas,
                v.sub_cuenta,
                (case
                  when fec_vencimiento - fec_apertura between 1 and 30 then
                   '20'
                  when fec_vencimiento - fec_apertura between 31 and 60 then
                   '30'
                  when fec_vencimiento - fec_apertura between 61 and 90 then
                   '40'
                  when fec_vencimiento - fec_apertura between 91 and 180 then
                   '50'
                  when fec_vencimiento - fec_apertura between 181 and 360 then
                   '60'
                  when fec_vencimiento - fec_apertura between 361 and 540 then
                   '71'
                  when fec_vencimiento - fec_apertura between 541 and 1080 then
                   '73'
                  when fec_vencimiento - fec_apertura > 1080 then
                   '80'
                  else
                   '10'
                end),
                v.exonera,
                v.cod_departamento
      Union all
      -- C.D.A. en estado Vencido.
      select v.moneda,
             v.cuentas,
             v.sub_cuenta,
             v.plazo,
             (Case
               when sum(v.monto) <= v_rango1 then
                '1'
               when sum(v.monto) > v_rango1 and sum(v.monto) <= v_rango2 then
                '2'
               when sum(v.monto) > v_rango2 and sum(v.monto) <= v_rango3 then
                '3'
               when sum(v.monto) > v_rango3 and sum(v.monto) <= v_rango4 then
                '4'
               when sum(v.monto) > v_rango4 and sum(v.monto) <= v_rango5 then
                '5'
               when sum(v.monto) >= v_rango6 then
                '6'
             end) rango,
             count(v.monto) cantidad,
             sum(nvl(v.monto, 0)),
             sum(nvl(v.mto_cta, 0)) mto_cta,
             v.cod_departamento,
             v.exonera
        from (select m.cod_mon_bco_central moneda,
                     substr(c.cod_rubro, 6, 3) cuentas,
                     substr(c.cod_rubro, 9, 2) sub_cuenta,
                     '10' plazo,
                     fub_con_mon_a_moneda(c.cod_moneda,
                                          v_cod_mon_local,
                                          d.sal_actual,
                                          null,
                                          c.fecha) monto,
                     d.sal_actual mto_cta,
                     d.nro_cuenta cuenta,
                     decode(nvl(fug_obt_paradicional(d.nro_cuenta,
                                                     'EXO_ENCAJES'),
                                'N'),
                            'N',
                            0,
                            1) exonera,
                     c.tip_saldo,
                     nvl(g.cod_departamento, 1) cod_departamento
                from cb_sal_inventarios_det_his d,
                     cb_sal_inventarios_his     c,
                     ba_monedas                 m,
                     ge_clientes                g,
                     ge_cta_clientes            ge
               where d.nro_referencia = c.nro_referencia
                 and c.cod_moneda = m.cod_moneda
                 and c.cod_modulo = 3
                 and c.cod_modalidad not in (31, 36, 334)
                 and c.tip_saldo in ('C', 'P', 'T')
                 and c.situacion = 'V'
                 and ge.nro_cuenta = d.nro_cuenta
                 and g.cod_persona = ge.cod_persona
                 and ge.relacion = 'P'
                 and nvl(c.sal_total, 0) != 0
                 and c.cod_rubro is not null
                 and d.fecha = c.fecha
                 and c.fecha = v_fec_proceso) v,
             ah_cta_certificados a
       where v.cuenta = a.nro_cuenta
       group by v.moneda,
                v.cuentas,
                v.sub_cuenta,
                v.plazo,
                v.exonera,
                v.cod_departamento
      Union all
      select v.moneda,
             v.cuentas,
             v.sub_cuenta,
             v.plazo,
             (Case
               when sum(v.monto) <= v_rango1 then
                '1'
               when sum(v.monto) > v_rango1 and sum(v.monto) <= v_rango2 then
                '2'
               when sum(v.monto) > v_rango2 and sum(v.monto) <= v_rango3 then
                '3'
               when sum(v.monto) > v_rango3 and sum(v.monto) <= v_rango4 then
                '4'
               when sum(v.monto) > v_rango4 and sum(v.monto) <= v_rango5 then
                '5'
               when sum(v.monto) >= v_rango6 then
                '6'
             end) rango,
             count(v.monto) cantidad,
             sum(nvl(v.monto, 0)) monto,
             sum(nvl(v.mto_cta, 0)) mto_cta,
             v.cod_departamento depto,
             v.exonera
        from (select m.cod_mon_bco_central moneda,
                     substr(c.cod_rubro, 6, 3) cuentas,
                     substr(c.cod_rubro, 9, 2) sub_cuenta,
                     '10' plazo,
                     fub_con_mon_a_moneda(c.cod_moneda,
                                          v_cod_mon_local,
                                          d.sal_actual,
                                          null,
                                          c.fecha) monto,
                     d.sal_actual mto_cta,
                     d.nro_cuenta cuenta,
                     decode(nvl(fug_obt_paradicional(d.nro_cuenta,
                                                     'EXO_ENCAJES'),
                                'N'),
                            'N',
                            0,
                            1) exonera,
                     c.tip_saldo,
                     nvl(g.cod_departamento, 1) cod_departamento
                from cb_sal_inventarios_det_his d,
                     cb_sal_inventarios_his     c,
                     ba_monedas                 m,
                     ge_clientes                g,
                     ge_cta_clientes            ge
               where d.nro_referencia = c.nro_referencia
                 and c.cod_moneda = m.cod_moneda
                 and c.cod_modulo = 4
                 and c.cod_modalidad in (42, 45, 48, 49, 442) -- RABP-CNF-03-11-2014: Diferencia en Encaje Legal, se agrega modulo 49
                 and c.tip_saldo = 'B'
                 and c.situacion = 'S'
                 and ge.nro_cuenta = d.nro_cuenta
                 and g.cod_persona = ge.cod_persona
                 and ge.relacion = 'P'
                 and nvl(c.sal_total, 0) != 0
                 and substr(c.cod_rubro, 6, 3) = '102' -- Se informa solamente el rubro 102.
                 and c.cod_rubro is not null
                 and d.fecha = c.fecha
                 and c.fecha = v_fec_proceso) v,
             cc_cta_bancarias a
       where v.cuenta = a.nro_cuenta
       group by v.moneda,
                v.cuentas,
                v.sub_cuenta,
                v.plazo,
                v.exonera,
                v.cod_departamento
      union all
      select v.moneda,
             v.cuentas,
             v.sub_cuenta,
             (case
               when fec_vencimiento - fec_apertura between 1 and 30 then
                '20'
               when fec_vencimiento - fec_apertura between 31 and 60 then
                '30'
               when fec_vencimiento - fec_apertura between 61 and 90 then
                '40'
               when fec_vencimiento - fec_apertura between 91 and 180 then
                '50'
               when fec_vencimiento - fec_apertura between 181 and 360 then
                '60'
               when fec_vencimiento - fec_apertura between 361 and 540 then
                '71'
               when fec_vencimiento - fec_apertura between 541 and 1080 then
                '73'
               when fec_vencimiento - fec_apertura > 1080 then
                '80'
               else
                '10'
             end) plazo,
             (Case
               when sum(v.monto) <= v_rango1 then
                '1'
               when sum(v.monto) > v_rango1 and sum(v.monto) <= v_rango2 then
                '2'
               when sum(v.monto) > v_rango2 and sum(v.monto) <= v_rango3 then
                '3'
               when sum(v.monto) > v_rango3 and sum(v.monto) <= v_rango4 then
                '4'
               when sum(v.monto) > v_rango4 and sum(v.monto) <= v_rango5 then
                '5'
               when sum(v.monto) >= v_rango6 then
                '6'
             end) rango,
             count(v.monto) cantidad,
             sum(nvl(v.monto, 0)),
             sum(nvl(v.mto_cta, 0)) mto_cta,
             v.cod_departamento,
             v.exonera
        from (select m.cod_mon_bco_central moneda,
                     substr(c.cod_rubro, 6, 3) cuentas,
                     substr(c.cod_rubro, 9, 2) sub_cuenta,
                     fub_con_mon_a_moneda(c.cod_moneda,
                                          v_cod_mon_local,
                                          d.sal_actual) monto,
                     d.sal_actual mto_cta,
                     d.nro_cuenta cuenta,
                     decode(nvl(fug_obt_paradicional(d.nro_cuenta,
                                                     'EXO_ENCAJES'),
                                'N'),
                            'N',
                            0,
                            1) exonera,
                     c.tip_saldo,
                     nvl(g.cod_departamento, 1) cod_departamento
                from cb_sal_inventarios_det_his d,
                     cb_sal_inventarios_his     c,
                     ba_monedas                 m,
                     ge_clientes                g,
                     ge_cta_clientes            ge
               where d.nro_referencia = c.nro_referencia
                 and c.cod_moneda = m.cod_moneda
                 and c.cod_modulo = 3
                 and c.cod_modalidad = 37
                 and c.tip_saldo in ('C', 'P', 'T')
                 and c.situacion = 'N'
                 and ge.nro_cuenta = d.nro_cuenta
                 and g.cod_persona = ge.cod_persona
                 and ge.relacion = 'P'
                 and nvl(c.sal_total, 0) != 0
                 and c.cod_rubro is not null
                 and d.fecha = c.fecha
                 and c.fecha = v_fec_proceso) v,
             ah_cta_plazos a
       where v.cuenta = a.nro_cuenta
       group by v.moneda,
                v.cuentas,
                v.sub_cuenta,
                (case
                  when fec_vencimiento - fec_apertura between 1 and 30 then
                   '20'
                  when fec_vencimiento - fec_apertura between 31 and 60 then
                   '30'
                  when fec_vencimiento - fec_apertura between 61 and 90 then
                   '40'
                  when fec_vencimiento - fec_apertura between 91 and 180 then
                   '50'
                  when fec_vencimiento - fec_apertura between 181 and 360 then
                   '60'
                  when fec_vencimiento - fec_apertura between 361 and 540 then
                   '71'
                  when fec_vencimiento - fec_apertura between 541 and 1080 then
                   '73'
                  when fec_vencimiento - fec_apertura > 1080 then
                   '80'
                  else
                   '10'
                end),
                v.exonera,
                v.cod_departamento
      union all
      -- Ahorro programado Normal
      select v.moneda,
             v.cuentas,
             v.sub_cuenta,
             '10' plazo,
             (Case
               when sum(v.monto) <= v_rango1 then
                '1'
               when sum(v.monto) > v_rango1 and sum(v.monto) <= v_rango2 then
                '2'
               when sum(v.monto) > v_rango2 and sum(v.monto) <= v_rango3 then
                '3'
               when sum(v.monto) > v_rango3 and sum(v.monto) <= v_rango4 then
                '4'
               when sum(v.monto) > v_rango4 and sum(v.monto) <= v_rango5 then
                '5'
               when sum(v.monto) >= v_rango6 then
                '6'
             end) rango,
             count(v.monto) cantidad,
             sum(nvl(v.monto, 0)),
             sum(nvl(v.mto_cta, 0)) mto_cta,
             v.cod_departamento,
             v.exonera
        from (select m.cod_mon_bco_central moneda,
                     substr(c.cod_rubro, 6, 3) cuentas,
                     substr(c.cod_rubro, 9, 2) sub_cuenta,
                     fub_con_mon_a_moneda(c.cod_moneda,
                                          v_cod_mon_local,
                                          d.sal_actual) monto,
                     d.sal_actual mto_cta,
                     d.nro_cuenta cuenta,
                     decode(nvl(fug_obt_paradicional(d.nro_cuenta,
                                                     'EXO_ENCAJES'),
                                'N'),
                            'N',
                            0,
                            1) exonera,
                     c.tip_saldo,
                     nvl(g.cod_departamento, 1) cod_departamento
                from cb_sal_inventarios_det_his d,
                     cb_sal_inventarios_his     c,
                     ba_monedas                 m,
                     ge_clientes                g,
                     ge_cta_clientes            ge
               where d.nro_referencia = c.nro_referencia
                 and c.cod_moneda = m.cod_moneda
                 and c.cod_modulo = 3
                 and c.cod_modalidad = 38
                 and c.tip_saldo in ('C', 'P', 'T')
                 and c.situacion = 'N'
                 and ge.nro_cuenta = d.nro_cuenta
                 and g.cod_persona = ge.cod_persona
                 and ge.relacion = 'P'
                 and nvl(c.sal_total, 0) != 0
                 and c.cod_rubro is not null
                 and d.fecha = c.fecha
                 and c.fecha = v_fec_proceso) v,
             ah_cta_plazos a
       where v.cuenta = a.nro_cuenta
       group by v.moneda,
                v.cuentas,
                v.sub_cuenta,
                v.exonera,
                v.cod_departamento
      Union all
      -- Cta. Plazo en estado Vencido.
      select v.moneda,
             v.cuentas,
             v.sub_cuenta,
             v.plazo,
             (Case
               when sum(v.monto) <= v_rango1 then
                '1'
               when sum(v.monto) > v_rango1 and sum(v.monto) <= v_rango2 then
                '2'
               when sum(v.monto) > v_rango2 and sum(v.monto) <= v_rango3 then
                '3'
               when sum(v.monto) > v_rango3 and sum(v.monto) <= v_rango4 then
                '4'
               when sum(v.monto) > v_rango4 and sum(v.monto) <= v_rango5 then
                '5'
               when sum(v.monto) >= v_rango6 then
                '6'
             end) rango,
             count(v.monto) cantidad,
             sum(nvl(v.monto, 0)),
             sum(nvl(v.mto_cta, 0)) mto_cta,
             v.cod_departamento,
             v.exonera
        from (select m.cod_mon_bco_central moneda,
                     substr(c.cod_rubro, 6, 3) cuentas,
                     substr(c.cod_rubro, 9, 2) sub_cuenta,
                     '10' plazo,
                     fub_con_mon_a_moneda(c.cod_moneda,
                                          v_cod_mon_local,
                                          d.sal_actual) monto,
                     d.sal_actual mto_cta,
                     d.nro_cuenta cuenta,
                     decode(nvl(fug_obt_paradicional(d.nro_cuenta,
                                                     'EXO_ENCAJES'),
                                'N'),
                            'N',
                            0,
                            1) exonera,
                     c.tip_saldo,
                     nvl(g.cod_departamento, 1) cod_departamento
                from cb_sal_inventarios_det_his d,
                     cb_sal_inventarios_his     c,
                     ba_monedas                 m,
                     ge_clientes                g,
                     ge_cta_clientes            ge
               where d.nro_referencia = c.nro_referencia
                 and c.cod_moneda = m.cod_moneda
                 and c.cod_modulo = 3
                 and c.cod_modalidad = 37
                 and c.tip_saldo in ('C', 'P', 'T')
                 and c.situacion = 'V'
                 and ge.nro_cuenta = d.nro_cuenta
                 and g.cod_persona = ge.cod_persona
                 and ge.relacion = 'P'
                 and nvl(c.sal_total, 0) != 0
                 and c.cod_rubro is not null
                 and d.fecha = c.fecha
                 and c.fecha = v_fec_proceso) v,
             ah_cta_plazos a
       where v.cuenta = a.nro_cuenta
       group by v.moneda,
                v.cuentas,
                v.sub_cuenta,
                v.plazo,
                v.exonera,
                v.cod_departamento
      union all
      -- Ahorro programado
      select v.moneda,
             v.cuentas,
             v.sub_cuenta,
             v.plazo,
             (Case
               when sum(v.monto) <= v_rango1 then
                '1'
               when sum(v.monto) > v_rango1 and sum(v.monto) <= v_rango2 then
                '2'
               when sum(v.monto) > v_rango2 and sum(v.monto) <= v_rango3 then
                '3'
               when sum(v.monto) > v_rango3 and sum(v.monto) <= v_rango4 then
                '4'
               when sum(v.monto) > v_rango4 and sum(v.monto) <= v_rango5 then
                '5'
               when sum(v.monto) >= v_rango6 then
                '6'
             end) rango,
             count(v.monto) cantidad,
             sum(nvl(v.monto, 0)),
             sum(nvl(v.mto_cta, 0)) mto_cta,
             v.cod_departamento,
             v.exonera
        from (select m.cod_mon_bco_central moneda,
                     substr(c.cod_rubro, 6, 3) cuentas,
                     substr(c.cod_rubro, 9, 2) sub_cuenta,
                     '10' plazo,
                     fub_con_mon_a_moneda(c.cod_moneda,
                                          v_cod_mon_local,
                                          d.sal_actual) monto,
                     d.sal_actual mto_cta,
                     d.nro_cuenta cuenta,
                     decode(nvl(fug_obt_paradicional(d.nro_cuenta,
                                                     'EXO_ENCAJES'),
                                'N'),
                            'N',
                            0,
                            1) exonera,
                     c.tip_saldo,
                     nvl(g.cod_departamento, 1) cod_departamento
                from cb_sal_inventarios_det_his d,
                     cb_sal_inventarios_his     c,
                     ba_monedas                 m,
                     ge_clientes                g,
                     ge_cta_clientes            ge
               where d.nro_referencia = c.nro_referencia
                 and c.cod_moneda = m.cod_moneda
                 and c.cod_modulo = 3
                 and c.cod_modalidad = 38
                 and c.tip_saldo in ('C', 'P', 'T')
                 and c.situacion = 'V'
                 and ge.nro_cuenta = d.nro_cuenta
                 and g.cod_persona = ge.cod_persona
                 and ge.relacion = 'P'
                 and nvl(c.sal_total, 0) != 0
                 and c.cod_rubro is not null
                 and d.fecha = c.fecha
                 and c.fecha = v_fec_proceso) v,
             ah_cta_plazos a
       where v.cuenta = a.nro_cuenta
       group by v.moneda,
                v.cuentas,
                v.sub_cuenta,
                v.plazo,
                v.exonera,
                v.cod_departamento
      union all
      select v.moneda,
             v.cuentas,
             v.sub_cuenta,
             v.plazo,
             (Case
               when sum(v.monto) <= v_rango1 then
                '1'
               when sum(v.monto) > v_rango1 and sum(v.monto) <= v_rango2 then
                '2'
               when sum(v.monto) > v_rango2 and sum(v.monto) <= v_rango3 then
                '3'
               when sum(v.monto) > v_rango3 and sum(v.monto) <= v_rango4 then
                '4'
               when sum(v.monto) > v_rango4 and sum(v.monto) <= v_rango5 then
                '5'
               when sum(v.monto) >= v_rango6 then
                '6'
             end) rango,
             count(v.monto) cantidad,
             sum(nvl(v.monto, 0)) monto,
             sum(nvl(v.mto_cta, 0)) mto_cta,
             v.cod_departamento depto,
             v.exonera
        from (select m.cod_mon_bco_central moneda,
                     substr(c.cod_rubro, 6, 3) cuentas,
                     substr(c.cod_rubro, 9, 2) sub_cuenta,
                     '10' plazo,
                     fub_con_mon_a_moneda(c.cod_moneda,
                                          v_cod_mon_local,
                                          d.sal_actual,
                                          null,
                                          c.fecha) monto,
                     d.sal_actual mto_cta,
                     d.nro_cuenta cuenta,
                     decode(nvl(fug_obt_paradicional(d.nro_cuenta,
                                                     'EXO_ENCAJES'),
                                'N'),
                            'N',
                            0,
                            1) exonera,
                     c.tip_saldo,
                     nvl(g.cod_departamento, 1) cod_departamento
                from cb_sal_inventarios_det_his d,
                     cb_sal_inventarios_his     c,
                     ba_monedas                 m,
                     ge_clientes                g,
                     ge_cta_clientes            ge
               where d.nro_referencia = c.nro_referencia
                 and c.cod_moneda = m.cod_moneda
                 and c.cod_modulo = 4
                 and c.cod_modalidad = 47
                 and ge.nro_cuenta = d.nro_cuenta
                 and g.cod_persona = ge.cod_persona
                 and ge.relacion = 'P'
                 and nvl(c.sal_total, 0) != 0
                 and c.cod_rubro is not null
                 and d.fecha = c.fecha
                 and c.fecha = v_fec_proceso) v,
             cc_cta_bancarias a
       where v.cuenta = a.nro_cuenta
         and a.denominacion = 'CUENTA EMBARGADA'
       group by v.moneda,
                v.cuentas,
                v.sub_cuenta,
                v.plazo,
                v.exonera,
                v.cod_departamento
      -- DYD-SDSL-2998: Bonos del Exterior
      union all
      select v.moneda,
             v.cuentas,
             v.sub_cuenta,
             (case
               when v.plazo = 1 then
                '10'
               when v.plazo = 2 then
                '20'
               when v.plazo = 3 then
                '30'
               when v.plazo = 4 then
                '40'
               when v.plazo = 5 then
                '50'
               when v.plazo = 6 then
                '60'
               when v.plazo = 7 then
                '70'
               when v.plazo = 8 then
                '80'
               when v.plazo = 9 then
                '90'
             end) plazo, --'80' plazo, --DYDMR-12072
             (Case
               when sum(v.monto) <= v_rango1 then
                '1'
               when sum(v.monto) > v_rango1 and sum(v.monto) <= v_rango2 then
                '2'
               when sum(v.monto) > v_rango2 and sum(v.monto) <= v_rango3 then
                '3'
               when sum(v.monto) > v_rango3 and sum(v.monto) <= v_rango4 then
                '4'
               when sum(v.monto) > v_rango4 and sum(v.monto) <= v_rango5 then
                '5'
               when sum(v.monto) >= v_rango6 then
                '6'
             end) rango,
             count(v.monto) cantidad,
             sum(nvl(v.monto, 0)) monto,
             sum(nvl(v.mto_cta, 0)) mto_cta,
             v.cod_departamento depto,
             v.exonera
        from (select m.cod_mon_bco_central moneda,
                     substr(c.cod_rubro, 6, 3) cuentas,
                     substr(c.cod_rubro, 9, 2) sub_cuenta,
                     --'10' plazo, --DYDMR-12072
                     c.cod_plazo plazo,
                     fub_con_mon_a_moneda(c.cod_moneda,
                                          v_cod_mon_local,
                                          d.sal_actual,
                                          null,
                                          c.fecha) monto,
                     d.sal_actual mto_cta,
                     d.nro_cuenta cuenta,
                     decode(nvl(fug_obt_paradicional(d.nro_cuenta,
                                                     'EXO_ENCAJES'),
                                'N'),
                            'N',
                            0,
                            1) exonera,
                     c.tip_saldo,
                     nvl(g.cod_departamento, 1) cod_departamento
                from cb_sal_inventarios_det_his d,
                     cb_sal_inventarios_his     c,
                     ba_monedas                 m,
                     ge_clientes                g,
                     ge_cta_clientes            ge
               where d.nro_referencia = c.nro_referencia
                 and c.cod_moneda = m.cod_moneda
                 and c.cod_modulo = 10
                 and c.cod_modalidad in (126, 145)
                 and c.tip_saldo = 'C'
                 and ge.nro_cuenta = d.nro_cuenta
                 and g.cod_persona = ge.cod_persona
                 and ge.relacion = 'P'
                 and nvl(c.sal_total, 0) != 0
                 and c.cod_rubro is not null
                 and d.fecha = c.fecha
                 and c.fecha = v_fec_proceso) v,
             md_cta_documentos a
       where v.cuenta = a.nro_cuenta
       group by v.moneda,
                v.cuentas,
                v.sub_cuenta,
                v.plazo,
                v.exonera,
                v.cod_departamento
       order by 1;

  BEGIN

    --Obtengo la fecha de generacion
    if P_FECHA is null then
      v_fec_proceso := fug_obt_pardinamico('FEC_GEN_ENC_ASCII');
    else
      v_fec_proceso := p_fecha;
    end if;
    v_cod_mon_local := pag_gen.FU_OBT_MON_LOCAL;

    --Verifico la existencia de registros
    DELETE sb_enc_circular254 where fecha = v_fec_proceso;

    --Obtengo el importe del salario minimo
    begin
      select sal_min_vigente into v_sal_min_vigente from pr_parametros;
    exception
      when others then
        raise_application_error(-20000,
                                'Error al recuperar pr_parametros.sal_min_vigente ' ||
                                sqlerrm);
    end;

    --Hasta 10 salarios minimos
    v_rango1 := v_sal_min_vigente * 10;
    --Mayor a 10 salarios minimos  hasta 75 salarios minimos
    v_rango2 := v_sal_min_vigente * 75;
    --Mayor a 75 salarios minimos  hasta 150 salarios minimos
    v_rango3 := v_sal_min_vigente * 150;
    --Mayor a 150 salarios minimos  hasta 250 salarios minimos
    v_rango4 := v_sal_min_vigente * 250;
    --Mayor a 250 salarios minimos  hasta 350 salarios minimos
    v_rango5 := v_sal_min_vigente * 350;
    --Mayor 350 salarios minimos
    v_rango6 := (v_sal_min_vigente * 350) + 1;
    --
    v_can_datos := v_can_datos + 1;
    --
    for reg in c_res_254 loop
      if reg.mto_cta > 0 then
        insert into sb_enc_circular254
          (fecha,
           nro_registro,
           cod_moneda,
           cod_cuenta,
           cod_subcuenta,
           plazo,
           rango,
           can_cuenta,
           importe,
           cta_departamento,
           enc_exonerado)
        values
          (v_fec_proceso,
           v_can_datos,
           reg.moneda,
           reg.cuentas,
           reg.sub_cuenta,
           reg.plazo,
           reg.rango,
           reg.cantidad,
           reg.mto_cta,
           reg.depto,
           reg.exonera);
        --
        v_can_datos := v_can_datos + 1;
      end if;
    end loop;
    /*
    || Circular SGGOF Nro 007/2020.
    */
    prs_gen_desencajes(v_fec_proceso,
                       'H',
                       v_sal_cap_cov_pyg,
                       v_cantidad_pyg,
                       v_sal_cap_cov_usd,
                       v_cantidad_usd);
    if nvl(v_sal_cap_cov_pyg, 0) <> 0 then
      insert into sb_enc_circular254
        (fecha,
         nro_registro,
         cod_moneda,
         cod_cuenta,
         cod_subcuenta,
         plazo,
         rango,
         can_cuenta,
         importe,
         cta_departamento,
         enc_exonerado)
      values
        (v_fec_proceso,
         v_can_datos,
         6900,
         '999',
         '99',
         '99',
         6,
         v_cantidad_pyg,
         v_sal_cap_cov_pyg,
         1,
         0);
      --
      v_can_datos := v_can_datos + 1;
    end if;
    if nvl(v_sal_cap_cov_usd, 0) <> 0 then
      insert into sb_enc_circular254
        (fecha,
         nro_registro,
         cod_moneda,
         cod_cuenta,
         cod_subcuenta,
         plazo,
         rango,
         can_cuenta,
         importe,
         cta_departamento,
         enc_exonerado)
      values
        (v_fec_proceso,
         v_can_datos,
         1,
         '999',
         '99',
         '99',
         6,
         v_cantidad_usd,
         v_sal_cap_cov_usd,
         1,
         0);
      --
      v_can_datos := v_can_datos + 1;
    end if;

  EXCEPTION
    when others then
      raise_application_error(-20000, sqlerrm || ' sb_encajes_ascii');
  END;
  --
  PROCEDURE PR_GEN_ENC_ASCII IS
    v_mes_proceso     VARCHAR2(08) DEFAULT '';
    v_nom_ascii       VARCHAR2(30) DEFAULT '';
    v_directorio      VARCHAR2(100) DEFAULT '';
    v_lin_datos       VARCHAR2(46);
    v_archivo         utl_file.file_type;
    v_fec_proceso     date;
    v_fec_contable    date;
    v_can_datos       number(4) default 0;
    v_can_reg         NUMBER(4) DEFAULT 0;
    v_per_entidad     ge_par_generales.cod_persona%type := fug_obt_per_entidad;
    v_cod_entidad     ge_par_generales.cod_entidad%TYPE;
    v_cod_mon_local   ba_monedas.cod_moneda%type;
    v_sal_cap_cov_pyg number(18, 2);
    v_cantidad_pyg    number;
    v_sal_cap_cov_usd number(18, 2);
    v_cantidad_usd    number;

    cursor c_res_254 is
    --AHORRO
      SELECT v.moneda,
             v.cuentas,
             v.sub_cuenta,
             v.plazo,
             (CASE
               WHEN SUM(nvl(v.monto_gs, 0)) <= v_rango1 THEN
                '1'
               WHEN SUM(nvl(v.monto_gs, 0)) > v_rango1 AND
                    SUM(nvl(v.monto_gs, 0)) <= v_rango2 THEN
                '2'
               WHEN SUM(nvl(v.monto_gs, 0)) > v_rango2 AND
                    SUM(nvl(v.monto_gs, 0)) <= v_rango3 THEN
                '3'
               WHEN SUM(nvl(v.monto_gs, 0)) > v_rango3 AND
                    SUM(nvl(v.monto_gs, 0)) <= v_rango4 THEN
                '4'
               WHEN SUM(nvl(v.monto_gs, 0)) > v_rango4 AND
                    SUM(nvl(v.monto_gs, 0)) <= v_rango5 THEN
                '5'
               WHEN SUM(nvl(v.monto_gs, 0)) >= v_rango6 THEN
                '6'
             END) rango,
             COUNT(v.monto) cantidad,
             SUM(v.monto) monto,
             --FARASOP-227 Se informa solo el monto, ya que en cb_sal_inventarios_det el saldo actual ya es menos el saldo retenido
             v.cod_departamento depto,
             v.exonera
        FROM (SELECT DISTINCT m.cod_mon_bco_central moneda,
                              substr(c.cod_rubro, 6, 3) cuentas,
                              substr(c.cod_rubro, 9, 2) sub_cuenta,
                              '10' plazo,
                              nvl(d.sal_actual, 0) monto,
                              decode(c.cod_moneda,
                                     v_cod_mon_local,
                                     nvl(d.sal_actual, 0),
                                     pag_gen.fu_obt_cotizacion(c.cod_moneda,
                                                               v_fec_proceso) *
                                     nvl(d.sal_actual, 0)) monto_gs,
                              d.nro_cuenta cuenta,
                              decode(nvl(fug_obt_paradicional(d.nro_cuenta,
                                                              'EXO_ENCAJES'),
                                         'N'),
                                     'N',
                                     0,
                                     1) exonera,
                              nvl(MAX(g.cod_departamento), 1) cod_departamento
                FROM cb_sal_inventarios_det     d,
                     cb_sal_inventarios         c,
                     ba_monedas                 m,
                     ge_clientes                g,
                     ge_cta_clientes            ge
               WHERE d.nro_referencia = c.nro_referencia
                 AND c.cod_moneda = m.cod_moneda
                 AND c.cod_modulo = 3
                 and instr(fug_obt_pardinamico('MAD_CAJ_AHORROS'),
                         c.cod_modalidad) > 0
                 AND c.tip_saldo = 'C'
                 AND ge.nro_cuenta = d.nro_cuenta
                 AND g.cod_persona = ge.cod_persona
                 AND nvl(d.sal_actual, 0) > 0
                 AND c.cod_rubro IS NOT NULL
               GROUP BY m.cod_mon_bco_central,
                        c.cod_moneda,
                        substr(c.cod_rubro, 6, 3),
                        substr(c.cod_rubro, 9, 2),
                        '10',
                        nvl(d.sal_actual, 0),
                        d.nro_cuenta,
                        decode(nvl(fug_obt_paradicional(d.nro_cuenta,
                                                        'EXO_ENCAJES'),
                                   'N'),
                               'N',
                               0,
                               1)) v,
             ah_cta_vistas a
       WHERE v.cuenta = a.nro_cuenta
         AND (a.est_batch NOT IN ('C') AND a.sal_tot_batch > 0) --Incluye ahv con est_bacth A y saldo mayor a 0
       GROUP BY v.moneda,
                v.cuentas,
                v.sub_cuenta,
                v.plazo,
                v.exonera,
                v.cod_departamento
      UNION
      --CDA
      SELECT v.moneda,
             v.cuentas,
             v.sub_cuenta,
             v.plazo,
             (CASE
               WHEN SUM(v.monto) <= v_rango1 THEN
                '1'
               WHEN SUM(v.monto) > v_rango1 AND SUM(v.monto) <= v_rango2 THEN
                '2'
               WHEN SUM(v.monto) > v_rango2 AND SUM(v.monto) <= v_rango3 THEN
                '3'
               WHEN SUM(v.monto) > v_rango3 AND SUM(v.monto) <= v_rango4 THEN
                '4'
               WHEN SUM(v.monto) > v_rango4 AND SUM(v.monto) <= v_rango5 THEN
                '5'
               WHEN SUM(v.monto) >= v_rango6 THEN
                '6'
             END) rango,
             COUNT(v.monto) cantidad,
             SUM(v.monto),
             v.cod_departamento,
             v.exonera
        FROM (SELECT DISTINCT m.cod_mon_bco_central moneda,
                              substr(rubro.cod_rubro, 6, 3) cuentas,
                              decode(substr(rubro.cod_rubro, 9, 2),
                                     'TD',
                                     ltrim(to_char(g.cod_tip_deudor, '00')),
                                     substr(rubro.cod_rubro, 9, 2)) sub_cuenta,
                              '10' plazo,
                              decode(ah.est_cer_batch,
                                     'V',
                                     nvl(ah.sal_tot_batch, 0),
                                     'P',
                                     nvl(ah.sal_tot_batch, 0),
                                     nvl(ah.sal_tot_batch, 0) -
                                     nvl(ah.capital, 0)) monto,
                              ah.nro_cuenta cuenta,
                              decode(nvl(fug_obt_paradicional(ah.nro_cuenta,
                                                              'EXO_ENCAJES'),
                                         'N'),
                                     'N',
                                     0,
                                     1) exonera,
                              nvl(MAX(g.cod_departamento), 1) cod_departamento
                FROM ah_cta_certificados ah,
                     ge_clientes g,
                     ge_cta_clientes cta,
                     ba_monedas m,
                     (SELECT t.cod_rubro,
                             t.cod_moneda,
                             t.cod_sec_contable,
                             t.ind_residente
                        FROM ge_tip_asientos t, ge_transacciones ge
                       WHERE t.cod_tip_asiento = ge.cod_tip_asiento
                         AND ge.cod_transaccion = 604
                         AND t.tip_movimiento = 'C') rubro -- Vencido
               WHERE est_batch NOT IN ('A', 'C', 'X')
                 AND (est_cer_batch IN ('V') OR
                     nvl(sal_tot_batch, 0) > nvl(capital, 0))
                 AND nvl(ah.sal_ret_batch, 0) = 0
                 AND ah.nro_cuenta = cta.nro_cuenta
                 AND cta.cod_persona = g.cod_persona
                 AND cta.relacion = 'P'
                 AND rubro.cod_moneda = ah.cod_moneda
                 AND g.cod_sec_contable = rubro.cod_sec_contable
                 AND g.residente = decode(rubro.ind_residente,
                                          'X',
                                          g.residente,
                                          rubro.ind_residente)
                 AND ah.cod_moneda = m.cod_moneda
               GROUP BY m.cod_mon_bco_central,
                        substr(rubro.cod_rubro, 6, 3),
                        decode(substr(rubro.cod_rubro, 9, 2),
                               'TD',
                               ltrim(to_char(g.cod_tip_deudor, '00')),
                               substr(rubro.cod_rubro, 9, 2)),
                        '10',
                        decode(ah.est_cer_batch,
                               'V',
                               nvl(ah.sal_tot_batch, 0),
                               'P',
                               nvl(ah.sal_tot_batch, 0),
                               nvl(ah.sal_tot_batch, 0) - nvl(ah.capital, 0)),
                        ah.nro_cuenta,
                        decode(nvl(fug_obt_paradicional(ah.nro_cuenta,
                                                        'EXO_ENCAJES'),
                                   'N'),
                               'N',
                               0,
                               1)) v,
             ah_cta_certificados a
       WHERE v.cuenta = a.nro_cuenta
         AND nvl(a.sal_ret_batch, 0) = 0
         AND a.est_batch NOT IN ('A', 'C', 'X')
         AND (a.est_cer_batch IN ('V', 'P') OR
             nvl(a.sal_tot_batch, 0) > nvl(a.capital, 0))
       AND instr(fug_obt_pardinamico('MAD_CER_AHORRO_EXC'), a.cod_modalidad || ',') = 0   
       GROUP BY v.moneda,
                v.cuentas,
                v.sub_cuenta,
                v.plazo,
                v.exonera,
                v.cod_departamento
      UNION
      -- para incluir cupones colgados
      SELECT v.moneda,
             v.cuentas,
             v.sub_cuenta,
             v.plazo,
             (CASE
               WHEN SUM(v.monto) <= v_rango1 THEN
                '1'
               WHEN SUM(v.monto) > v_rango1 AND SUM(v.monto) <= v_rango2 THEN
                '2'
               WHEN SUM(v.monto) > v_rango2 AND SUM(v.monto) <= v_rango3 THEN
                '3'
               WHEN SUM(v.monto) > v_rango3 AND SUM(v.monto) <= v_rango4 THEN
                '4'
               WHEN SUM(v.monto) > v_rango4 AND SUM(v.monto) <= v_rango5 THEN
                '5'
               WHEN SUM(v.monto) >= v_rango6 THEN
                '6'
             END) rango,
             COUNT(v.monto) cantidad,
             SUM(v.monto),
             v.cod_departamento,
             v.exonera
        FROM (SELECT DISTINCT m.cod_mon_bco_central moneda,
                              substr(rubro.cod_rubro, 6, 3) cuentas,
                              decode(substr(rubro.cod_rubro, 9, 2),
                                     'TD',
                                     ltrim(to_char(g.cod_tip_deudor, '00')),
                                     substr(rubro.cod_rubro, 9, 2)) sub_cuenta,
                              '10' plazo,
                              nvl(ah.sal_tot_batch, 0) monto,
                              ah.nro_cuenta cuenta,
                              decode(nvl(fug_obt_paradicional(ah.nro_cuenta,
                                                              'EXO_ENCAJES'),
                                         'N'),
                                     'N',
                                     0,
                                     1) exonera,
                              nvl(MAX(g.cod_departamento), 1) cod_departamento
                FROM ah_cta_certificados ah,
                     ge_clientes g,
                     ge_cta_clientes cta,
                     ba_monedas m,
                     (SELECT t.cod_rubro,
                             t.cod_moneda,
                             t.cod_sec_contable,
                             t.ind_residente
                        FROM ge_tip_asientos t, ge_transacciones ge
                       WHERE t.cod_tip_asiento = ge.cod_tip_asiento
                         AND ge.cod_transaccion = 604
                         AND t.tip_movimiento = 'C') rubro -- Vencido
               WHERE est_batch IN ('P', 'V') --Agregado por diferencias de Cupones Vencidos sin Capital de CDA
                 AND est_cer_batch IN ('E', 'P')
                 AND nvl(ah.sal_ret_batch, 0) = 0
                 AND ah.nro_cuenta = cta.nro_cuenta
                 AND cta.cod_persona = g.cod_persona
                 AND cta.relacion = 'P'
                 AND rubro.cod_moneda = ah.cod_moneda
                 AND g.cod_sec_contable = rubro.cod_sec_contable
                 AND g.residente = decode(rubro.ind_residente,
                                          'X',
                                          g.residente,
                                          rubro.ind_residente)
                 AND ah.cod_moneda = m.cod_moneda
               GROUP BY m.cod_mon_bco_central,
                        substr(rubro.cod_rubro, 6, 3),
                        decode(substr(rubro.cod_rubro, 9, 2),
                               'TD',
                               ltrim(to_char(g.cod_tip_deudor, '00')),
                               substr(rubro.cod_rubro, 9, 2)),
                        '10',
                        nvl(ah.sal_tot_batch, 0),
                        ah.nro_cuenta,
                        decode(nvl(fug_obt_paradicional(ah.nro_cuenta,
                                                        'EXO_ENCAJES'),
                                   'N'),
                               'N',
                               0,
                               1)) v,
             ah_cta_certificados a
       WHERE v.cuenta = a.nro_cuenta
         AND nvl(a.sal_ret_batch, 0) = 0
         AND a.est_batch IN ('P', 'V') --Agregado por diferencias de Cupones Vencidos sin Capital de CDA
         AND a.est_cer_batch IN ('E', 'P')
       GROUP BY v.moneda,
                v.cuentas,
                v.sub_cuenta,
                v.plazo,
                v.exonera,
                v.cod_departamento
      UNION
      SELECT v.moneda,
             v.cuentas,
             v.sub_cuenta,
             (CASE
               WHEN fec_vencimiento - fec_apertura BETWEEN 0 AND 30 THEN
                '20'
               WHEN fec_vencimiento - fec_apertura BETWEEN 31 AND 60 THEN
                '30'
               WHEN fec_vencimiento - fec_apertura BETWEEN 61 AND 90 THEN
                '40'
               WHEN fec_vencimiento - fec_apertura BETWEEN 91 AND 180 THEN
                '50'
               WHEN fec_vencimiento - fec_apertura BETWEEN 181 AND 360 THEN
                '60'
               WHEN fec_vencimiento - fec_apertura BETWEEN 361 AND 540 THEN
                '71'
               WHEN fec_vencimiento - fec_apertura BETWEEN 541 AND 1080 THEN
                '73'
               WHEN fec_vencimiento - fec_apertura > 1080 THEN
                '80'
             END) plazo,
             (CASE
               WHEN SUM(v.monto_gs) <= v_rango1 THEN
                '1'
               WHEN SUM(v.monto_gs) > v_rango1 AND
                    SUM(v.monto_gs) <= v_rango2 THEN
                '2'
               WHEN SUM(v.monto_gs) > v_rango2 AND
                    SUM(v.monto_gs) <= v_rango3 THEN
                '3'
               WHEN SUM(v.monto_gs) > v_rango3 AND
                    SUM(v.monto_gs) <= v_rango4 THEN
                '4'
               WHEN SUM(v.monto_gs) > v_rango4 AND
                    SUM(v.monto_gs) <= v_rango5 THEN
                '5'
               WHEN SUM(v.monto_gs) >= v_rango6 THEN
                '6'
             END) rango,
             COUNT(v.monto) cantidad,
             SUM(v.monto) monto,
             v.cod_departamento,
             v.exonera
        FROM (SELECT DISTINCT m.cod_mon_bco_central moneda,
                              substr(c.cod_rubro, 6, 3) cuentas,
                              substr(c.cod_rubro, 9, 2) sub_cuenta,
                              nvl(d.sal_actual, 0) monto,
                              decode(c.cod_moneda,
                                     v_cod_mon_local,
                                     nvl(d.sal_actual, 0),
                                     pag_gen.fu_obt_cotizacion(c.cod_moneda,
                                                               v_fec_proceso) *
                                     nvl(d.sal_actual, 0)) monto_gs,
                              d.nro_cuenta cuenta,
                              decode(nvl(fug_obt_paradicional(d.nro_cuenta,
                                                              'EXO_ENCAJES'),
                                         'N'),
                                     'N',
                                     0,
                                     1) exonera,
                              nvl(MAX(g.cod_departamento), 1) cod_departamento
                FROM cb_sal_inventarios_det     d,
                     cb_sal_inventarios         c,
                     ba_monedas                 m,
                     ge_clientes                g,
                     ge_cta_clientes            ge
               WHERE d.nro_referencia = c.nro_referencia               
                 AND c.cod_moneda = m.cod_moneda
                 AND c.cod_modulo = 3
                 AND c.cod_modalidad not in ( 31,36)
                 AND c.tip_saldo = 'C'
                 AND c.situacion != 'V' --Vencido
                 AND ge.nro_cuenta = d.nro_cuenta
                 AND g.cod_persona = ge.cod_persona
                 AND nvl(d.sal_actual, 0) > 0
                 AND c.cod_rubro IS NOT NULL
               GROUP BY m.cod_mon_bco_central,
                        c.cod_moneda,
                        substr(c.cod_rubro, 6, 3),
                        substr(c.cod_rubro, 9, 2),
                        nvl(d.sal_actual, 0),
                        d.nro_cuenta,
                        decode(nvl(fug_obt_paradicional(d.nro_cuenta,
                                                        'EXO_ENCAJES'),
                                   'N'),
                               'N',
                               0,
                               1)) v,
             ah_cta_certificados a
       WHERE v.cuenta = a.nro_cuenta
         AND a.est_batch in ('N', 'B')
         AND nvl(a.sal_ret_batch, 0) = 0
         AND a.est_cer_batch NOT IN ('V', 'P')--Ni vencido ni Pendiente
         AND a.est_batch NOT IN ('T', 'A', 'C', 'X')
       GROUP BY v.moneda,
                v.cuentas,
                v.sub_cuenta,
                (CASE
                  WHEN fec_vencimiento - fec_apertura BETWEEN 0 AND 30 THEN
                   '20'
                  WHEN fec_vencimiento - fec_apertura BETWEEN 31 AND 60 THEN
                   '30'
                  WHEN fec_vencimiento - fec_apertura BETWEEN 61 AND 90 THEN
                   '40'
                  WHEN fec_vencimiento - fec_apertura BETWEEN 91 AND 180 THEN
                   '50'
                  WHEN fec_vencimiento - fec_apertura BETWEEN 181 AND 360 THEN
                   '60'
                  WHEN fec_vencimiento - fec_apertura BETWEEN 361 AND 540 THEN
                   '71'
                  WHEN fec_vencimiento - fec_apertura BETWEEN 541 AND 1080 THEN
                   '73'
                  WHEN fec_vencimiento - fec_apertura > 1080 THEN
                   '80'
                END),
                v.exonera,
                v.cod_departamento
      UNION
      -- para incluir cupones vencidos de cda totalmente pagados
      SELECT v.moneda,
             v.cuentas,
             v.sub_cuenta,
             v.plazo,
             (CASE
               WHEN SUM(v.monto) <= v_rango1 THEN
                '1'
               WHEN SUM(v.monto) > v_rango1 AND SUM(v.monto) <= v_rango2 THEN
                '2'
               WHEN SUM(v.monto) > v_rango2 AND SUM(v.monto) <= v_rango3 THEN
                '3'
               WHEN SUM(v.monto) > v_rango3 AND SUM(v.monto) <= v_rango4 THEN
                '4'
               WHEN SUM(v.monto) > v_rango4 AND SUM(v.monto) <= v_rango5 THEN
                '5'
               WHEN SUM(v.monto) >= v_rango6 THEN
                '6'
             END) rango,
             COUNT(v.monto) cantidad,
             SUM(v.monto),
             v.cod_departamento,
             v.exonera
        FROM (SELECT DISTINCT m.cod_mon_bco_central moneda,
                              substr(rubro.cod_rubro, 6, 3) cuentas,
                              decode(substr(rubro.cod_rubro, 9, 2),
                                     'TD',
                                     ltrim(to_char(g.cod_tip_deudor, '00')),
                                     substr(rubro.cod_rubro, 9, 2)) sub_cuenta,
                              '10' plazo,
                              nvl(ah.sal_tot_batch, 0) monto,
                              ah.nro_cuenta cuenta,
                              decode(nvl(fug_obt_paradicional(ah.nro_cuenta,
                                                              'EXO_ENCAJES'),
                                         'N'),
                                     'N',
                                     0,
                                     1) exonera,
                              nvl(MAX(g.cod_departamento), 1) cod_departamento
                FROM ah_cta_certificados ah,
                     ge_clientes g,
                     ge_cta_clientes cta,
                     ba_monedas m,
                     (SELECT t.cod_rubro,
                             t.cod_moneda,
                             t.cod_sec_contable,
                             t.ind_residente
                        FROM ge_tip_asientos t, ge_transacciones ge
                       WHERE t.cod_tip_asiento = ge.cod_tip_asiento
                         AND ge.cod_transaccion = 604
                         AND t.tip_movimiento = 'C') rubro -- Vencido
               WHERE est_batch = 'T'
                 AND nvl(ah.sal_ret_batch, 0) = 0
                 and exists (select 1 from ah_cupones cup where cup.nro_cuenta = ah.nro_cuenta and cup.estado = 'V')
                 AND ah.nro_cuenta = cta.nro_cuenta
                 AND cta.cod_persona = g.cod_persona
                 AND cta.relacion = 'P'
                 AND rubro.cod_moneda = ah.cod_moneda
                 AND g.cod_sec_contable = rubro.cod_sec_contable
                 AND g.residente = decode(rubro.ind_residente,
                                          'X',
                                          g.residente,
                                          rubro.ind_residente)
                 AND ah.cod_moneda = m.cod_moneda
               GROUP BY m.cod_mon_bco_central,
                        substr(rubro.cod_rubro, 6, 3),
                        decode(substr(rubro.cod_rubro, 9, 2),
                               'TD',
                               ltrim(to_char(g.cod_tip_deudor, '00')),
                               substr(rubro.cod_rubro, 9, 2)),
                        '10',
                        nvl(ah.sal_tot_batch, 0),
                        ah.nro_cuenta,
                        decode(nvl(fug_obt_paradicional(ah.nro_cuenta,
                                                        'EXO_ENCAJES'),
                                   'N'),
                               'N',
                               0,
                               1)) v,
             ah_cta_certificados a
       WHERE v.cuenta = a.nro_cuenta
         AND nvl(a.sal_ret_batch, 0) = 0
         AND a.est_batch = 'T'
       GROUP BY v.moneda,
                v.cuentas,
                v.sub_cuenta,
                v.plazo,
                v.exonera,
                v.cod_departamento
      union all
      --Cta Corriente
      select v.moneda,
             v.cuentas,
             v.sub_cuenta,
             v.plazo,
             (Case
               when sum(v.monto_gs) <= v_rango1 then
                '1'
               when sum(v.monto_gs) > v_rango1 and sum(v.monto_gs) <= v_rango2 then
                '2'
               when sum(v.monto_gs) > v_rango2 and sum(v.monto_gs) <= v_rango3 then
                '3'
               when sum(v.monto_gs) > v_rango3 and sum(v.monto_gs) <= v_rango4 then
                '4'
               when sum(v.monto_gs) > v_rango4 and sum(v.monto_gs) <= v_rango5 then
                '5'
               when sum(v.monto_gs) >= v_rango6 then
                '6'
             end) rango,
             count(v.monto) cantidad,
             sum(nvl(v.monto, 0)) monto,
             v.cod_departamento depto,
             v.exonera
        from (select m.cod_mon_bco_central moneda,
                     substr(c.cod_rubro, 6, 3) cuentas,
                     substr(c.cod_rubro, 9, 2) sub_cuenta,
                     '10' plazo,
                     nvl(d.sal_actual, 0) monto,
                     fub_con_mon_a_moneda(c.cod_moneda,
                                          v_cod_mon_local,
                                          nvl(d.sal_actual,0)) monto_gs,
                     d.sal_actual mto_cta,
                     d.nro_cuenta cuenta,
                     decode(nvl(fug_obt_paradicional(d.nro_cuenta,
                                                     'EXO_ENCAJES'),
                                'N'),
                            'N',
                            0,
                            1) exonera,
                     c.tip_saldo,
                     nvl(g.cod_departamento, 1) cod_departamento
                from cb_sal_inventarios_det d,
                     cb_sal_inventarios     c,
                     ba_monedas             m,
                     ge_clientes            g,
                     ge_cta_clientes        ge
               where d.nro_referencia = c.nro_referencia
                 and c.cod_moneda = m.cod_moneda
                 and c.cod_modulo = 4
                 and c.cod_modalidad = 41
                 and c.tip_saldo in ('C', 'P', 'T')
                 and c.situacion = 'N'
                 and ge.nro_cuenta = d.nro_cuenta
                 and g.cod_persona = ge.cod_persona
                 and ge.relacion = 'P'
                 and nvl(c.sal_total, 0) != 0
                 and c.cod_rubro is not null) v,
             cc_cta_corrientes a
       where v.cuenta = a.nro_cuenta
       group by v.moneda,
                v.cuentas,
                v.sub_cuenta,
                v.plazo,
                v.exonera,
                v.cod_departamento
      union all
      select v.moneda,
             v.cuentas,
             v.sub_cuenta,
             v.plazo,
             (Case
               when sum(v.monto_gs) <= v_rango1 then
                '1'
               when sum(v.monto_gs) > v_rango1 and sum(v.monto_gs) <= v_rango2 then
                '2'
               when sum(v.monto_gs) > v_rango2 and sum(v.monto_gs) <= v_rango3 then
                '3'
               when sum(v.monto_gs) > v_rango3 and sum(v.monto_gs) <= v_rango4 then
                '4'
               when sum(v.monto_gs) > v_rango4 and sum(v.monto_gs) <= v_rango5 then
                '5'
               when sum(v.monto_gs) >= v_rango6 then
                '6'
             end) rango,
             count(v.monto) cantidad,
             sum(nvl(v.monto, 0)) monto,
             v.cod_departamento depto,
             v.exonera
        from (select m.cod_mon_bco_central moneda,
                     substr(c.cod_rubro, 6, 3) cuentas,
                     substr(c.cod_rubro, 9, 2) sub_cuenta,
                     '10' plazo,
                     nvl(d.sal_actual, 0) monto,
                     fub_con_mon_a_moneda(c.cod_moneda,
                                          v_cod_mon_local,
                                          d.sal_actual) monto_gs,
                     d.sal_actual mto_cta,
                     d.nro_cuenta cuenta,
                     decode(nvl(fug_obt_paradicional(d.nro_cuenta,
                                                     'EXO_ENCAJES'),
                                'N'),
                            'N',
                            0,
                            1) exonera,
                     c.tip_saldo,
                     nvl(g.cod_departamento, 1) cod_departamento
                from cb_sal_inventarios_det d,
                     cb_sal_inventarios     c,
                     ba_monedas             m,
                     ge_clientes            g,
                     ge_cta_clientes        ge
               where d.nro_referencia = c.nro_referencia
                 and c.cod_moneda = m.cod_moneda
                 and c.cod_modulo = 4
                 and c.cod_modalidad = 41
                 and c.tip_saldo = 'Q'
                 and ge.nro_cuenta = d.nro_cuenta
                 and g.cod_persona = ge.cod_persona
                 and ge.relacion = 'P'
                 and nvl(c.sal_total, 0) != 0
                 and c.cod_rubro is not null) v,
             cc_cta_corrientes a
       where v.cuenta = a.nro_cuenta
       group by v.moneda,
                v.cuentas,
                v.sub_cuenta,
                v.plazo,
                v.exonera,
                v.cod_departamento
      union all
      --Cheque Certificado.
      select v.moneda,
             v.cuentas,
             v.sub_cuenta,
             v.plazo,
             (Case
               when sum(v.monto_gs) <= v_rango1 then
                '1'
               when sum(v.monto_gs) > v_rango1 and sum(v.monto_gs) <= v_rango2 then
                '2'
               when sum(v.monto_gs) > v_rango2 and sum(v.monto_gs) <= v_rango3 then
                '3'
               when sum(v.monto_gs) > v_rango3 and sum(v.monto_gs) <= v_rango4 then
                '4'
               when sum(v.monto_gs) > v_rango4 and sum(v.monto_gs) <= v_rango5 then
                '5'
               when sum(v.monto_gs) >= v_rango6 then
                '6'
             end) rango,
             count(v.monto) cantidad,
             sum(nvl(v.monto, 0)) monto,
             v.cod_departamento depto,
             v.exonera
        from (select m.cod_mon_bco_central moneda,
                     substr(c.cod_rubro, 6, 3) cuentas,
                     substr(c.cod_rubro, 9, 2) sub_cuenta,
                     '10' plazo,
                     nvl(d.sal_actual, 0) monto,
                     fub_con_mon_a_moneda(c.cod_moneda,
                                          v_cod_mon_local,
                                          d.sal_actual) monto_gs,
                     d.sal_actual mto_cta,
                     d.nro_cuenta cuenta,
                     decode(nvl(fug_obt_paradicional(d.nro_cuenta,
                                                     'EXO_ENCAJES'),
                                'N'),
                            'N',
                            0,
                            1) exonera,
                     c.tip_saldo,
                     nvl(g.cod_departamento, 1) cod_departamento
                from cb_sal_inventarios_det d,
                     cb_sal_inventarios     c,
                     ba_monedas             m,
                     ge_clientes            g,
                     ge_cta_clientes        ge
               where d.nro_referencia = c.nro_referencia
                 and c.cod_moneda = m.cod_moneda
                 and c.cod_modulo = 4
                 and c.cod_modalidad = 41
                 and c.tip_saldo = 'C'
                 and c.situacion is null
                 and ge.nro_cuenta = d.nro_cuenta
                 and g.cod_persona = ge.cod_persona
                 and ge.relacion = 'P'
                 and nvl(c.sal_total, 0) != 0
                 and c.cod_rubro is not null) v,
             cc_cta_corrientes a
       where v.cuenta = a.nro_cuenta
         and exists
       (select 1
                from cc_che_certificados ch, cc_cta_bancarias cb
               where ch.nro_cuenta = a.nro_cuenta
                 and ch.nro_cta_certificado = cb.nro_cuenta
                 and ch.fec_pago IS NULL)
       group by v.moneda,
                v.cuentas,
                v.sub_cuenta,
                v.plazo,
                v.exonera,
                v.cod_departamento
      union all
      -- Cta. Plazo en estado Normal.
      select v.moneda,
             v.cuentas,
             v.sub_cuenta,
             (case
               when fec_vencimiento - fec_apertura between 1 and 30 then
                '20'
               when fec_vencimiento - fec_apertura between 31 and 60 then
                '30'
               when fec_vencimiento - fec_apertura between 61 and 90 then
                '40'
               when fec_vencimiento - fec_apertura between 91 and 180 then
                '50'
               when fec_vencimiento - fec_apertura between 181 and 360 then
                '60'
               when fec_vencimiento - fec_apertura between 361 and 540 then
                '71'
               when fec_vencimiento - fec_apertura between 541 and 1080 then
                '73'
               when fec_vencimiento - fec_apertura > 1080 then
                '80'
               else
                '10'
             end) plazo,
             (Case
               when sum(v.monto_gs) <= v_rango1 then
                '1'
               when sum(v.monto_gs) > v_rango1 and sum(v.monto_gs) <= v_rango2 then
                '2'
               when sum(v.monto_gs) > v_rango2 and sum(v.monto_gs) <= v_rango3 then
                '3'
               when sum(v.monto_gs) > v_rango3 and sum(v.monto_gs) <= v_rango4 then
                '4'
               when sum(v.monto_gs) > v_rango4 and sum(v.monto_gs) <= v_rango5 then
                '5'
               when sum(v.monto_gs) >= v_rango6 then
                '6'
             end) rango,
             count(v.monto) cantidad,
             sum(nvl(v.monto, 0)),
             v.cod_departamento,
             v.exonera
        from (select m.cod_mon_bco_central moneda,
                     substr(c.cod_rubro, 6, 3) cuentas,
                     substr(c.cod_rubro, 9, 2) sub_cuenta,
                     nvl(d.sal_actual, 0) monto,
                     fub_con_mon_a_moneda(c.cod_moneda,
                                          v_cod_mon_local,
                                          d.sal_actual) monto_gs,
                     d.sal_actual mto_cta,
                     d.nro_cuenta cuenta,
                     decode(nvl(fug_obt_paradicional(d.nro_cuenta,
                                                     'EXO_ENCAJES'),
                                'N'),
                            'N',
                            0,
                            1) exonera,
                     c.tip_saldo,
                     nvl(g.cod_departamento, 1) cod_departamento
                from cb_sal_inventarios_det d,
                     cb_sal_inventarios     c,
                     ba_monedas             m,
                     ge_clientes            g,
                     ge_cta_clientes        ge
               where d.nro_referencia = c.nro_referencia
                 and c.cod_moneda = m.cod_moneda
                 and c.cod_modulo = 3
                 and c.cod_modalidad = 37
                 and c.tip_saldo in ('C', 'P', 'T')
                 and c.situacion = 'N'
                 and ge.nro_cuenta = d.nro_cuenta
                 and g.cod_persona = ge.cod_persona
                 and ge.relacion = 'P'
                 and nvl(c.sal_total, 0) != 0
                 and c.cod_rubro is not null) v,
             ah_cta_plazos a
       where v.cuenta = a.nro_cuenta
       group by v.moneda,
                v.cuentas,
                v.sub_cuenta,
                (case
                  when fec_vencimiento - fec_apertura between 1 and 30 then
                   '20'
                  when fec_vencimiento - fec_apertura between 31 and 60 then
                   '30'
                  when fec_vencimiento - fec_apertura between 61 and 90 then
                   '40'
                  when fec_vencimiento - fec_apertura between 91 and 180 then
                   '50'
                  when fec_vencimiento - fec_apertura between 181 and 360 then
                   '60'
                  when fec_vencimiento - fec_apertura between 361 and 540 then
                   '71'
                  when fec_vencimiento - fec_apertura between 541 and 1080 then
                   '73'
                  when fec_vencimiento - fec_apertura > 1080 then
                   '80'
                  else
                   '10'
                end),
                v.exonera,
                v.cod_departamento
      --Ahorro programado
      Union all
      select v.moneda,
             v.cuentas,
             v.sub_cuenta,
             (case
               when round((fec_vencimiento - fec_apertura)/2) between 1 and 30 then
                '20'
               when  round((fec_vencimiento - fec_apertura)/2) between 31 and 60 then
                '30'
               when round((fec_vencimiento - fec_apertura)/2)  between 61 and 90 then
                '40'
               when round((fec_vencimiento - fec_apertura)/2) between 91 and 180 then
                '50'
               when round((fec_vencimiento - fec_apertura)/2) between 181 and 360 then
                '60'
               when round((fec_vencimiento - fec_apertura)/2) between 361 and 540 then
                '71'
               when round((fec_vencimiento - fec_apertura)/2) between 541 and 1080 then
                '73'
               when round((fec_vencimiento - fec_apertura)/2) > 1080 then
                '80'
               else
                '10'
             end) plazo,
             (Case
               when sum(v.monto_gs) <= v_rango1 then
                '1'
               when sum(v.monto_gs) > v_rango1 and sum(v.monto_gs) <= v_rango2 then
                '2'
               when sum(v.monto_gs) > v_rango2 and sum(v.monto_gs) <= v_rango3 then
                '3'
               when sum(v.monto_gs) > v_rango3 and sum(v.monto_gs) <= v_rango4 then
                '4'
               when sum(v.monto_gs) > v_rango4 and sum(v.monto_gs) <= v_rango5 then
                '5'
               when sum(v.monto_gs) >= v_rango6 then
                '6'
             end) rango,
             count(v.monto) cantidad,
             sum(nvl(v.monto, 0)),
             v.cod_departamento,
             v.exonera
        from (select m.cod_mon_bco_central moneda,
                     substr(c.cod_rubro, 6, 3) cuentas,
                     substr(c.cod_rubro, 9, 2) sub_cuenta,
                     nvl(d.sal_actual, 0) monto,
                     fub_con_mon_a_moneda(c.cod_moneda,
                                          v_cod_mon_local,
                                          d.sal_actual) monto_gs,
                     d.sal_actual mto_cta,
                     d.nro_cuenta cuenta,
                     decode(nvl(fug_obt_paradicional(d.nro_cuenta,
                                                     'EXO_ENCAJES'),
                                'N'),
                            'N',
                            0,
                            1) exonera,
                     c.tip_saldo,
                     nvl(g.cod_departamento, 1) cod_departamento
                from cb_sal_inventarios_det d,
                     cb_sal_inventarios     c,
                     ba_monedas             m,
                     ge_clientes            g,
                     ge_cta_clientes        ge
               where d.nro_referencia = c.nro_referencia                 
                 and c.cod_moneda = m.cod_moneda
                 and c.cod_modulo = 3
                 and c.cod_modalidad =fug_obt_pardinamico('MAD_AHO_PROGRAMADO')
                 and c.tip_saldo in ('C', 'P', 'T')
                 and c.situacion = 'N'
                 and ge.nro_cuenta = d.nro_cuenta
                 and g.cod_persona = ge.cod_persona
                 and ge.relacion = 'P'
                 and nvl(c.sal_total, 0) != 0
                 and c.cod_rubro is not null) v,
             ah_cta_plazos a
       where v.cuenta = a.nro_cuenta
       group by v.moneda,
                v.cuentas,
                v.sub_cuenta,
                (case
                  when round((fec_vencimiento - fec_apertura)/2)  between 1 and 30 then
                   '20'
                  when  round((fec_vencimiento - fec_apertura)/2) between 31 and 60 then
                   '30'
                  when  round((fec_vencimiento - fec_apertura)/2) between 61 and 90 then
                   '40'
                  when  round((fec_vencimiento - fec_apertura)/2) between 91 and 180 then
                   '50'
                  when  round((fec_vencimiento - fec_apertura)/2) between 181 and 360 then
                   '60'
                  when  round((fec_vencimiento - fec_apertura)/2) between 361 and 540 then
                   '71'
                  when  round((fec_vencimiento - fec_apertura)/2) between 541 and 1080 then
                   '73'
                  when  round((fec_vencimiento - fec_apertura)/2) > 1080 then
                   '80'
                  else
                   '10'
                end),
                v.exonera,
                v.cod_departamento
      Union all
      -- Cta. Plazo en estado Vencido.
      select v.moneda,
             v.cuentas,
             v.sub_cuenta,
             v.plazo,
             (Case
               when sum(v.monto_gs) <= v_rango1 then
                '1'
               when sum(v.monto_gs) > v_rango1 and sum(v.monto_gs) <= v_rango2 then
                '2'
               when sum(v.monto_gs) > v_rango2 and sum(v.monto_gs) <= v_rango3 then
                '3'
               when sum(v.monto_gs) > v_rango3 and sum(v.monto_gs) <= v_rango4 then
                '4'
               when sum(v.monto_gs) > v_rango4 and sum(v.monto_gs) <= v_rango5 then
                '5'
               when sum(v.monto_gs) >= v_rango6 then
                '6'
             end) rango,
             count(v.monto) cantidad,
             sum(nvl(v.monto, 0)),
             v.cod_departamento,
             v.exonera
        from (select m.cod_mon_bco_central moneda,
                     substr(c.cod_rubro, 6, 3) cuentas,
                     substr(c.cod_rubro, 9, 2) sub_cuenta,
                     '10' plazo,
                     nvl(d.sal_actual, 0) monto,
                     fub_con_mon_a_moneda(c.cod_moneda,
                                          v_cod_mon_local,
                                          d.sal_actual) monto_gs,
                     d.sal_actual mto_cta,
                     d.nro_cuenta cuenta,
                     decode(nvl(fug_obt_paradicional(d.nro_cuenta,
                                                     'EXO_ENCAJES'),
                                'N'),
                            'N',
                            0,
                            1) exonera,
                     c.tip_saldo,
                     nvl(g.cod_departamento, 1) cod_departamento
                from cb_sal_inventarios_det d,
                     cb_sal_inventarios     c,
                     ba_monedas             m,
                     ge_clientes            g,
                     ge_cta_clientes        ge
               where d.nro_referencia = c.nro_referencia
                 and c.cod_moneda = m.cod_moneda
                 and c.cod_modulo = 3
                 and c.cod_modalidad = 37
                 and c.tip_saldo in ('C', 'P', 'T')
                 and c.situacion = 'V'
                 and ge.nro_cuenta = d.nro_cuenta
                 and g.cod_persona = ge.cod_persona
                 and ge.relacion = 'P'
                 and nvl(c.sal_total, 0) != 0
                 and c.cod_rubro is not null) v,
             ah_cta_plazos a
       where v.cuenta = a.nro_cuenta
       group by v.moneda,
                v.cuentas,
                v.sub_cuenta,
                v.plazo,
                v.exonera,
                v.cod_departamento
      Union all
      -- Ahorro programado en estado Vencido.
      select v.moneda,
             v.cuentas,
             v.sub_cuenta,
             v.plazo,
             (Case
               when sum(v.monto_gs) <= v_rango1 then
                '1'
               when sum(v.monto_gs) > v_rango1 and sum(v.monto_gs) <= v_rango2 then
                '2'
               when sum(v.monto_gs) > v_rango2 and sum(v.monto_gs) <= v_rango3 then
                '3'
               when sum(v.monto_gs) > v_rango3 and sum(v.monto_gs) <= v_rango4 then
                '4'
               when sum(v.monto_gs) > v_rango4 and sum(v.monto_gs) <= v_rango5 then
                '5'
               when sum(v.monto_gs) >= v_rango6 then
                '6'
             end) rango,
             count(v.monto) cantidad,
             sum(nvl(v.monto, 0)),
             v.cod_departamento,
             v.exonera
        from (select m.cod_mon_bco_central moneda,
                     substr(c.cod_rubro, 6, 3) cuentas,
                     substr(c.cod_rubro, 9, 2) sub_cuenta,
                     '10' plazo,
                     nvl(d.sal_actual, 0) monto,
                     fub_con_mon_a_moneda(c.cod_moneda,
                                          v_cod_mon_local,
                                          d.sal_actual) monto_gs,
                     d.sal_actual mto_cta,
                     d.nro_cuenta cuenta,
                     decode(nvl(fug_obt_paradicional(d.nro_cuenta,
                                                     'EXO_ENCAJES'),
                                'N'),
                            'N',
                            0,
                            1) exonera,
                     c.tip_saldo,
                     nvl(g.cod_departamento, 1) cod_departamento
                from cb_sal_inventarios_det d,
                     cb_sal_inventarios     c,
                     ba_monedas             m,
                     ge_clientes            g,
                     ge_cta_clientes        ge
               where d.nro_referencia = c.nro_referencia
                 and c.cod_moneda = m.cod_moneda
                 and c.cod_modulo = 3
                 and c.cod_modalidad =fug_obt_pardinamico('MAD_AHO_PROGRAMADO')
                 and c.tip_saldo in ('C', 'P', 'T')
                 and c.situacion = 'V'
                 and ge.nro_cuenta = d.nro_cuenta
                 and g.cod_persona = ge.cod_persona
                 and ge.relacion = 'P'
                 and nvl(c.sal_total, 0) != 0
                 and c.cod_rubro is not null) v,
             ah_cta_plazos a
       where v.cuenta = a.nro_cuenta
       group by v.moneda,
                v.cuentas,
                v.sub_cuenta,
                v.plazo,
                v.exonera,
                v.cod_departamento
      Union all
      select v.moneda,
             v.cuentas,
             v.sub_cuenta,
             v.plazo,
             (Case
               when sum(v.monto_gs) <= v_rango1 then
                '1'
               when sum(v.monto_gs) > v_rango1 and sum(v.monto_gs) <= v_rango2 then
                '2'
               when sum(v.monto_gs) > v_rango2 and sum(v.monto_gs) <= v_rango3 then
                '3'
               when sum(v.monto_gs) > v_rango3 and sum(v.monto_gs) <= v_rango4 then
                '4'
               when sum(v.monto_gs) > v_rango4 and sum(v.monto_gs) <= v_rango5 then
                '5'
               when sum(v.monto_gs) >= v_rango6 then
                '6'
             end) rango,
             count(v.monto) cantidad,
             sum(nvl(v.monto, 0)) monto,
             v.cod_departamento depto,
             v.exonera
        from (select m.cod_mon_bco_central moneda,
                     substr(c.cod_rubro, 6, 3) cuentas,
                     substr(c.cod_rubro, 9, 2) sub_cuenta,
                     '10' plazo,
                     nvl(d.sal_actual, 0) monto,
                     fub_con_mon_a_moneda(c.cod_moneda,
                                          v_cod_mon_local,
                                          d.sal_actual) monto_gs,
                     d.sal_actual mto_cta,
                     d.nro_cuenta cuenta,
                     decode(nvl(fug_obt_paradicional(d.nro_cuenta,
                                                     'EXO_ENCAJES'),
                                'N'),
                            'N',
                            0,
                            1) exonera,
                     c.tip_saldo,
                     nvl(g.cod_departamento, 1) cod_departamento
                from cb_sal_inventarios_det d,
                     cb_sal_inventarios     c,
                     ba_monedas             m,
                     ge_clientes            g,
                     ge_cta_clientes        ge
               where d.nro_referencia = c.nro_referencia
                 and c.cod_moneda = m.cod_moneda
                 and c.cod_modulo = 4
                 and c.cod_modalidad in (42, 45, 48, 49, 442) -- RABP-CNF-03-11-2014: Diferencia en Encaje Legal, se agrega modulo 49
                 and c.tip_saldo = 'B'
                 and c.situacion = 'S'
                 and ge.nro_cuenta = d.nro_cuenta
                 and g.cod_persona = ge.cod_persona
                 and ge.relacion = 'P'
                 and nvl(c.sal_total, 0) != 0
                 and substr(c.cod_rubro, 6, 3) = '102' -- Se informa solamente el rubro 102.
                 and c.cod_rubro is not null) v,
             cc_cta_bancarias a
       where v.cuenta = a.nro_cuenta
       group by v.moneda,
                v.cuentas,
                v.sub_cuenta,
                v.plazo,
                v.exonera,
                v.cod_departamento
      union all
      select v.moneda,
             v.cuentas,
             v.sub_cuenta,
             v.plazo,
             (Case
               when sum(v.monto_gs) <= v_rango1 then
                '1'
               when sum(v.monto_gs) > v_rango1 and sum(v.monto_gs) <= v_rango2 then
                '2'
               when sum(v.monto_gs) > v_rango2 and sum(v.monto_gs) <= v_rango3 then
                '3'
               when sum(v.monto_gs) > v_rango3 and sum(v.monto_gs) <= v_rango4 then
                '4'
               when sum(v.monto_gs) > v_rango4 and sum(v.monto_gs) <= v_rango5 then
                '5'
               when sum(v.monto_gs) >= v_rango6 then
                '6'
             end) rango,
             count(v.monto) cantidad,
             sum(nvl(v.monto, 0)) monto,
             v.cod_departamento depto,
             v.exonera
        from (select m.cod_mon_bco_central moneda,
                     substr(c.cod_rubro, 6, 3) cuentas,
                     substr(c.cod_rubro, 9, 2) sub_cuenta,
                     '10' plazo,
                     nvl(d.sal_actual, 0) monto,
                     fub_con_mon_a_moneda(c.cod_moneda,
                                          v_cod_mon_local,
                                          d.sal_actual) monto_gs,
                     d.sal_actual mto_cta,
                     d.nro_cuenta cuenta,
                     decode(nvl(fug_obt_paradicional(d.nro_cuenta,
                                                     'EXO_ENCAJES'),
                                'N'),
                            'N',
                            0,
                            1) exonera,
                     c.tip_saldo,
                     nvl(g.cod_departamento, 1) cod_departamento
                from cb_sal_inventarios_det d,
                     cb_sal_inventarios     c,
                     ba_monedas             m,
                     ge_clientes            g,
                     ge_cta_clientes        ge
               where d.nro_referencia = c.nro_referencia
                 and c.cod_moneda = m.cod_moneda
                 and c.cod_modulo = 4
                 and c.cod_modalidad = 47
                 and ge.nro_cuenta = d.nro_cuenta
                 and g.cod_persona = ge.cod_persona
                 and ge.relacion = 'P'
                 and nvl(c.sal_total, 0) != 0
                 and c.cod_rubro is not null) v,
             cc_cta_bancarias a
       where v.cuenta = a.nro_cuenta
         and a.denominacion = 'CUENTA EMBARGADA'
       group by v.moneda,
                v.cuentas,
                v.sub_cuenta,
                v.plazo,
                v.exonera,
                v.cod_departamento
      -- Bonos del Exterior
    UNION ALL
    SELECT v.moneda,
           v.cuentas,
           v.sub_cuenta,
           (CASE
               WHEN fec_vencimiento - fec_inicio BETWEEN 0 AND 30 THEN
                '20'
               WHEN fec_vencimiento - fec_inicio BETWEEN 31 AND 60 THEN
                '30'
               WHEN fec_vencimiento - fec_inicio BETWEEN 61 AND 90 THEN
                '40'
               WHEN fec_vencimiento - fec_inicio BETWEEN 91 AND 180 THEN
                '50'
               WHEN fec_vencimiento - fec_inicio BETWEEN 181 AND 360 THEN
                '60'
               WHEN fec_vencimiento - fec_inicio BETWEEN 361 AND 540 THEN
                '71'
               WHEN fec_vencimiento - fec_inicio BETWEEN 541 AND 1080 THEN
                '73'
               WHEN fec_vencimiento - fec_inicio > 1080 THEN
                '80'
             END) plazo,
           (CASE
             WHEN SUM(v.monto_gs) <= v_rango1 THEN
              '1'
             WHEN SUM(v.monto_gs) > v_rango1 AND SUM(v.monto_gs) <= v_rango2 THEN
              '2'
             WHEN SUM(v.monto_gs) > v_rango2 AND SUM(v.monto_gs) <= v_rango3 THEN
              '3'
             WHEN SUM(v.monto_gs) > v_rango3 AND SUM(v.monto_gs) <= v_rango4 THEN
              '4'
             WHEN SUM(v.monto_gs) > v_rango4 AND SUM(v.monto_gs) <= v_rango5 THEN
              '5'
             WHEN SUM(v.monto_gs) >= v_rango6 THEN
              '6'
           END) rango,
           COUNT(v.monto) cantidad,
           SUM(v.monto) monto,
           v.cod_departamento depto,
           v.exonera
      FROM (SELECT m.cod_mon_bco_central moneda,
                   substr(c.cod_rubro, 6, 3) cuentas,
                   substr(c.cod_rubro, 9, 2) sub_cuenta,
                   nvl(d.sal_actual, 0) monto,
                   fub_con_mon_a_moneda(c.cod_moneda,
                                          v_cod_mon_local,
                                          d.sal_actual) monto_gs,
                   d.nro_cuenta cuenta,
                   decode(nvl(fug_obt_paradicional(d.nro_cuenta,
                                                   'EXO_ENCAJES'),
                              'N'),
                          'N',
                          0,
                          1) exonera,
                   c.tip_saldo,
                   nvl(g.cod_departamento, 1) cod_departamento
              FROM cb_sal_inventarios_det d,
                   cb_sal_inventarios     c,
                   ba_monedas             m,
                   ge_clientes            g,
                   ge_cta_clientes        ge
             WHERE d.nro_referencia = c.nro_referencia
               AND c.cod_moneda = m.cod_moneda
               AND c.cod_modulo = 10
               AND c.tip_saldo = 'C'
               AND ge.nro_cuenta = d.nro_cuenta
               AND g.cod_persona = ge.cod_persona
               AND ge.relacion = 'P'
               AND nvl(c.sal_total, 0) != 0
               AND c.cod_rubro IS NOT NULL
               AND instr(',' || fug_obt_pardinamico('MDD_MAD_BONOS_ENCAJE') || ',', ',' || c.cod_modalidad || ',') > 0
                   ) v,
           md_cta_documentos a
     WHERE v.cuenta = a.nro_cuenta
     GROUP BY v.moneda,
              v.cuentas,
              v.sub_cuenta,
              (CASE
               WHEN fec_vencimiento - fec_inicio BETWEEN 0 AND 30 THEN
                '20'
               WHEN fec_vencimiento - fec_inicio BETWEEN 31 AND 60 THEN
                '30'
               WHEN fec_vencimiento - fec_inicio BETWEEN 61 AND 90 THEN
                '40'
               WHEN fec_vencimiento - fec_inicio BETWEEN 91 AND 180 THEN
                '50'
               WHEN fec_vencimiento - fec_inicio BETWEEN 181 AND 360 THEN
                '60'
               WHEN fec_vencimiento - fec_inicio BETWEEN 361 AND 540 THEN
                '71'
               WHEN fec_vencimiento - fec_inicio BETWEEN 541 AND 1080 THEN
                '73'
               WHEN fec_vencimiento - fec_inicio > 1080 THEN
                '80'
             END),
              v.exonera,
              v.cod_departamento
     ORDER BY 1;

    CURSOR c_archivo IS
    SELECT a.cod_moneda,
           a.cod_cuenta,
           a.plazo,
           a.rango,
           SUM(a.can_cuenta) can_cuenta,
           SUM(a.importe) importe,
           a.cta_departamento,
           a.enc_exonerado
      FROM sb_enc_circular254 a
     WHERE a.fecha = v_fec_proceso
     GROUP BY a.cod_moneda,
              a.cod_cuenta,
              a.plazo,
              a.rango,
              a.cta_departamento,
              a.enc_exonerado;
  BEGIN
    v_directorio  := fug_obt_pardinamico('DIR_REP_FTP');
    --Obtengo la fecha de generacion
    v_fec_contable  := nvl(pag_cal.fu_obt_fec_actual(2),
                           pag_cal.fu_obt_fec_actual(1));                 
    v_cod_mon_local := pag_gen.FU_OBT_MON_LOCAL;
    v_fec_proceso := pag_cal.fu_obt_fec_actual(1);  

    if v_fec_proceso < v_fec_contable then
      v_fec_proceso := v_fec_contable;
    end if;
    --Verifico la existencia de registros
    DELETE sb_enc_circular254 where fecha = v_fec_proceso;

    --Obtengo el importe del salario minimo
    begin
      select sal_min_vigente into v_sal_min_vigente from pr_parametros;
    exception
      when others then
        raise_application_error(-20000,
                                'Error al recuperar pr_parametros.sal_min_vigente ' ||
                                sqlerrm);
    end;

    --Hasta 10 salarios minimos
    v_rango1 := v_sal_min_vigente * 10;
    --Mayor a 10 salarios minimos  hasta 75 salarios minimos
    v_rango2 := v_sal_min_vigente * 75;
    --Mayor a 75 salarios minimos  hasta 150 salarios minimos
    v_rango3 := v_sal_min_vigente * 150;
    --Mayor a 150 salarios minimos  hasta 250 salarios minimos
    v_rango4 := v_sal_min_vigente * 250;
    --Mayor a 250 salarios minimos  hasta 350 salarios minimos
    v_rango5 := v_sal_min_vigente * 350;
    --Mayor 350 salarios minimos
    v_rango6 := (v_sal_min_vigente * 350) + 1;
    --
    v_can_datos := v_can_datos + 1;

    IF utl_file.is_open(v_archivo) THEN
    utl_file.fclose(v_archivo);
  END IF;
  --- Procesar archivo personas PS
  v_nom_ascii := v_cod_entidad || v_mes_proceso || 'PA.txt';
  v_archivo   := utl_file.fopen(v_directorio, v_nom_ascii, 'w');
  v_can_datos := v_can_datos + 1;

    for reg in c_res_254 loop
      if reg.monto > 0 then
        insert into sb_enc_circular254
          (fecha,
           nro_registro,
           cod_moneda,
           cod_cuenta,
           cod_subcuenta,
           plazo,
           rango,
           can_cuenta,
           importe,
           cta_departamento,
           enc_exonerado)
        values
          (v_fec_proceso,
           v_can_datos,
           reg.moneda,
           reg.cuentas,
           reg.sub_cuenta,
           reg.plazo,
           reg.rango,
           reg.cantidad,
           reg.monto,
           reg.depto,
           reg.exonera);
        --
        v_can_datos := v_can_datos + 1;
      end if;
    end loop;


    FOR arc IN c_archivo LOOP
    v_can_reg   := v_can_reg + 1;
    v_lin_datos := lpad(to_char(v_can_reg), 4, '0');
    v_lin_datos := v_lin_datos || lpad(TRIM(arc.cod_moneda), 4, '0');
    v_lin_datos := v_lin_datos || lpad(TRIM(arc.cod_cuenta), 3, '0');
    v_lin_datos := v_lin_datos || lpad(TRIM('00'), 2, '0');
    v_lin_datos := v_lin_datos || lpad(TRIM(arc.plazo), 2, '0');
    v_lin_datos := v_lin_datos || lpad(TRIM(arc.rango), 2, '0');
    v_lin_datos := v_lin_datos ||
                   lpad(TRIM(to_char(arc.can_cuenta)), 9, '0');
    v_lin_datos := v_lin_datos || lpad(REPLACE(REPLACE(TRIM(to_char(arc.importe,
                                                                    '99,999,999,999.99')),
                                                       ',',
                                                       ''),
                                               '.',
                                               ''),
                                       17,
                                       '0');
    v_lin_datos := v_lin_datos || lpad(TRIM(arc.cta_departamento), 2, '0');
    v_lin_datos := v_lin_datos || lpad(TRIM(arc.enc_exonerado), 1, '0');
    utl_file.put_line(v_archivo, v_lin_datos);
  END LOOP;
  utl_file.fclose(v_archivo);

    -- Para generar circuito de aprobaci?n
    IF fug_obt_pardinamico('INI_CIR_APR_MT998') = 'S' THEN
      IF paw_cir.fu_ini_circuito(933, 1, 1) <> 0 THEN
        raise_application_error(-20005,
                                'Error al ejecutar el PAW_CIR.FU_INI_CIRCUITO: ' ||
                                SQLERRM);
      END IF;
    END IF;
    --

  EXCEPTION  
  WHEN no_data_found THEN
    --- Fin del archivo
    utl_file.fclose(v_archivo);
  WHEN utl_file.invalid_path THEN
    utl_file.fclose(v_archivo);
    raise_application_error(-20000, 'Directorio invalido');
  WHEN utl_file.invalid_mode THEN
    utl_file.fclose(v_archivo);
    raise_application_error(-20000, 'Modo invalido');
  WHEN utl_file.invalid_filehandle THEN
    utl_file.fclose(v_archivo);
    raise_application_error(-20000, 'Invalida Filehandle');
  WHEN utl_file.invalid_operation THEN
    --- Fin del archivo
    utl_file.fclose(v_archivo);
  WHEN utl_file.read_error THEN
    utl_file.fclose(v_archivo);
    raise_application_error(-20000, 'Lectura errada');
  WHEN utl_file.write_error THEN
    utl_file.fclose(v_archivo);
    raise_application_error(-20000, 'Escritura errada');
  WHEN utl_file.internal_error THEN
    utl_file.fclose(v_archivo);
    raise_application_error(-20000, 'Error interno');
    WHEN others THEN
      raise_application_error(-20000, sqlerrm || ' sb_encajes_ascii');
  END;

  --- Circular 263 - Analisis de Liquidez --Cierre Operativo -- Inventario
  PROCEDURE PR_INS_LIQ_DIA_INV(p_fecha IN DATE DEFAULT NULL) IS

    --VARIABLES
    v_lugar       VARCHAR2(1000) := NULL;
    v_fec_proceso ge_calendarios.fec_actual%TYPE;
    v_mon_local   ba_monedas.cod_moneda%TYPE := pag_gen.fu_obt_mon_local;
    v_mon_fuerte  ba_monedas.cod_moneda%type := pag_gen.fu_obt_mon_fuerte;
    v_control     NUMBER := 0;

    --Cursores
    CURSOR c_res_263 is

    --PRESTAMOS (solo capital por cuotas) --
      SELECT v.moneda,
             v.cuentas,
             (CASE
               WHEN cuentas like '16%' THEN
                '10'
               WHEN dias <= 0 OR dias = 1 THEN
                '11'
               WHEN dias = 2 THEN
                '12'
               WHEN dias = 3 THEN
                '13'
               WHEN dias = 4 THEN
                '14'
               WHEN dias = 5 THEN
                '15'
               WHEN dias BETWEEN 6 AND 15 THEN
                '20'
               WHEN dias BETWEEN 16 AND 30 THEN
                '30'
               WHEN dias BETWEEN 31 AND 60 THEN
                '40'
               WHEN dias BETWEEN 61 AND 90 THEN
                '50'
               WHEN dias BETWEEN 91 AND 180 THEN
                '60'
               WHEN dias BETWEEN 181 AND 365 THEN
                '70'
               WHEN dias > 365 THEN
                '80'
             END) plazo,
             nvl(SUM(v.monto), 0) monto
        FROM (SELECT decode(c.cod_moneda,
                            v_mon_local,
                            m.cod_mon_bco_central,
                            '6100') moneda,
                     decode(substr(r.cod_rub_padre, 1, 5),
                            '22010',
                            rpad(to_char(r.cod_rub_padre), 10, '0'),
                            decode(substr(r.cod_rub_padre, 1, 5),
                                   '14010',
                                   rpad(to_char(r.cod_rub_padre), 10, '0'),
                                   decode(substr(r.cod_rub_padre, 1, 10),
                                          '12010123060',
                                          '12010123006',
                                          decode(substr(r.cod_rub_padre, 1, 10),
                                                 '12010123080',
                                                 '12010123008',
                                                 rpad(to_char(r.cod_rub_padre),
                                                      10,
                                                      '0'))))) cuentas,
                     (CASE
                       WHEN c.cod_moneda NOT IN (v_mon_local, v_mon_fuerte) and
                            c.cod_modalidad not in (670, 671) THEN
                        fub_con_mon_a_moneda(c.cod_moneda,
                                             v_mon_fuerte,
                                             pc.sal_capital)
                       WHEN c.cod_moneda IN (v_mon_local, v_mon_fuerte) and
                            c.cod_modalidad not in (670, 671) THEN
                        pc.sal_capital
                       WHEN c.cod_moneda IN (v_mon_local, v_mon_fuerte) and
                            c.cod_modalidad in (670, 671) THEN
                        nvl(pc.sal_capital, 0) + nvl(pc.sal_interes, 0) +
                        nvl(pc.sal_int_documentado, 0)
                     END) monto,
                     decode(c.cod_moneda,
                            v_mon_local,
                            pc.sal_capital,
                            pag_gen.fu_obt_cotizacion(c.cod_moneda,
                                                      v_fec_proceso) *
                            pc.sal_capital) monto_gs,
                     d.nro_cuenta cuenta,
                     (CASE
                       WHEN pr.cod_modalidad IN (675, 677) THEN
                        1
                       ELSE
                        (nvl(pc.fec_vencimiento, v_fec_proceso) -
                        v_fec_proceso)
                     END) dias
                FROM cb_sal_inventarios_det     d,
                     cb_sal_inventarios         c,
                     cb_rubros                  r,
                     ba_monedas                 m,
                     ge_clientes                g,
                     ge_cta_clientes            ge,
                     pr_cta_prestamos           pr,
                     pr_cuotas                  pc
               WHERE c.nro_referencia = d.nro_referencia
                 AND c.cod_rubro = r.cod_rubro
                 AND c.cod_moneda = m.cod_moneda
                 AND c.cod_modulo = 6
                 AND c.tip_saldo IN ('C', 'F') -- Capital
                 AND ge.nro_cuenta = d.nro_cuenta
                 AND g.cod_persona = ge.cod_persona
                 AND ge.relacion = 'P'
                 AND nvl(d.sal_actual, 0) != 0
                 AND c.cod_rubro IS NOT NULL
                 AND d.nro_cuenta = pr.nro_cuenta
                 AND pr.nro_cuenta = pc.nro_cuenta
                 AND pc.nro_cuota > 0
                 AND pc.estado != 'N') v
       GROUP BY v.moneda,
                v.cuentas,
                (CASE
                  WHEN cuentas like '16%' THEN
                   '10'
                  WHEN dias <= 0 OR dias = 1 THEN
                   '11'
                  WHEN dias = 2 THEN
                   '12'
                  WHEN dias = 3 THEN
                   '13'
                  WHEN dias = 4 THEN
                   '14'
                  WHEN dias = 5 THEN
                   '15'
                  WHEN dias BETWEEN 6 AND 15 THEN
                   '20'
                  WHEN dias BETWEEN 16 AND 30 THEN
                   '30'
                  WHEN dias BETWEEN 31 AND 60 THEN
                   '40'
                  WHEN dias BETWEEN 61 AND 90 THEN
                   '50'
                  WHEN dias BETWEEN 91 AND 180 THEN
                   '60'
                  WHEN dias BETWEEN 181 AND 365 THEN
                   '70'
                  WHEN dias > 365 THEN
                   '80'
                END)
      UNION ALL
      --PRESTAMOS ( solo Interes Devengado no cobrado por cuota ) --
      SELECT v.moneda,
             v.cuentas,
             (CASE
               WHEN cuentas like '16%' THEN
                '10'
               WHEN v.dias in (0, 1) THEN
                '11'
               WHEN v.dias = 2 THEN
                '12'
               WHEN v.dias = 3 THEN
                '13'
               WHEN v.dias = 4 THEN
                '14'
               WHEN v.dias = 5 THEN
                '15'
               WHEN v.dias BETWEEN 6 AND 15 THEN
                '20'
               WHEN v.dias BETWEEN 16 AND 30 THEN
                '30'
               WHEN v.dias BETWEEN 31 AND 60 THEN
                '40'
               WHEN v.dias BETWEEN 61 AND 90 THEN
                '50'
               WHEN v.dias BETWEEN 91 AND 180 THEN
                '60'
               WHEN v.dias BETWEEN 181 AND 365 THEN
                '70'
               WHEN v.dias > 365 THEN
                '80'
             END) plazo,
             nvl(SUM(v.monto), 0) monto
        FROM (SELECT decode(c.cod_moneda,
                            v_mon_local,
                            m.cod_mon_bco_central,
                            '6100') moneda,
                     decode(substr(r.cod_rub_padre, 1, 5),
                            '22010',
                            rpad(to_char(r.cod_rub_padre), 10, '0'),
                            decode(substr(r.cod_rub_padre, 1, 5),
                                   '14010',
                                   rpad(to_char(r.cod_rub_padre), 10, '0'),
                                   decode(substr(r.cod_rub_padre, 1, 10),
                                          '12010123060',
                                          '12010123006',
                                          decode(substr(r.cod_rub_padre, 1, 10),
                                                 '12010123080',
                                                 '12010123008',
                                                 rpad(to_char(r.cod_rub_padre),
                                                      10,
                                                      '0'))))) cuentas,
                     (case
                       when c.cod_moneda not in (v_mon_local, v_mon_fuerte) then
                        FUB_CON_MON_A_MONEDA(c.cod_moneda,
                                             v_mon_fuerte,
                                             case
                                               when c.tip_saldo in ('A','S') then
                                                sal_actual * -1
                                               else
                                                sal_actual
                                             end)
                       else
                        (case
                          when c.tip_saldo in  ('A','S') then
                           sal_actual * -1
                          else
                           sal_actual
                        end)
                     end) monto,
                     decode(c.cod_moneda,
                            v_mon_local,
                            d.sal_actual,
                            pag_gen.fu_obt_cotizacion(c.cod_moneda,
                                                      v_fec_proceso) *
                            d.sal_actual) monto_gs,
                     d.nro_cuenta cuenta,
                     (CASE
                       WHEN pr.cod_modalidad IN (675, 677) THEN
                        1
                       WHEN pr.fec_vencimiento < v_fec_proceso THEN
                        v_fec_proceso - pr.fec_vencimiento
                       ELSE
                        (nvl(pr.fec_vencimiento, v_fec_proceso) -
                        v_fec_proceso)
                     END) dias
                FROM cb_sal_inventarios_det     d,
                     cb_sal_inventarios         c,
                     cb_rubros                  r,
                     ba_monedas                 m,
                     ge_clientes                g,
                     ge_cta_clientes            ge,
                     pr_cta_prestamos           pr
               WHERE d.nro_referencia = c.nro_referencia
                 AND c.cod_rubro = r.cod_rubro
                 AND c.cod_moneda = m.cod_moneda
                 AND c.cod_modulo = 6
                 AND c.tip_saldo IN ('A', 'I','S') -- Interes a Cobrar.
                 AND ge.nro_cuenta = d.nro_cuenta
                 AND g.cod_persona = ge.cod_persona
                 AND nvl(d.sal_actual, 0) != 0
                 AND ge.relacion = 'P'
                 AND c.cod_rubro IS NOT NULL
                 AND d.nro_cuenta = pr.nro_cuenta) v
       GROUP BY v.moneda,
                v.cuentas,
                (CASE
                  WHEN cuentas like '16%' THEN
                   '10'
                  WHEN v.dias in (0, 1) THEN
                   '11'
                  WHEN v.dias = 2 THEN
                   '12'
                  WHEN v.dias = 3 THEN
                   '13'
                  WHEN v.dias = 4 THEN
                   '14'
                  WHEN v.dias = 5 THEN
                   '15'
                  WHEN v.dias BETWEEN 6 AND 15 THEN
                   '20'
                  WHEN v.dias BETWEEN 16 AND 30 THEN
                   '30'
                  WHEN v.dias BETWEEN 31 AND 60 THEN
                   '40'
                  WHEN v.dias BETWEEN 61 AND 90 THEN
                   '50'
                  WHEN v.dias BETWEEN 91 AND 180 THEN
                   '60'
                  WHEN v.dias BETWEEN 181 AND 365 THEN
                   '70'
                  WHEN v.dias > 365 THEN
                   '80'
                END)
      UNION
      --- PREVISIONES DE PRESTAMOS
      SELECT v.moneda,
             v.cuentas,
             (CASE
               WHEN cuentas like '16%' THEN
                '10'
               WHEN dias <= 0 OR dias = 1 THEN
                '11'
               WHEN dias = 2 THEN
                '12'
               WHEN dias = 3 THEN
                '13'
               WHEN dias = 4 THEN
                '14'
               WHEN dias = 5 THEN
                '15'
               WHEN dias BETWEEN 6 AND 15 THEN
                '20'
               WHEN dias BETWEEN 16 AND 30 THEN
                '30'
               WHEN dias BETWEEN 31 AND 60 THEN
                '40'
               WHEN dias BETWEEN 61 AND 90 THEN
                '50'
               WHEN dias BETWEEN 91 AND 180 THEN
                '60'
               WHEN dias BETWEEN 181 AND 365 THEN
                '70'
               WHEN dias > 365 THEN
                '80'
             END) plazo,
             nvl(SUM(v.monto), 0) monto
        FROM (SELECT decode(c.cod_moneda,
                            'GS',
                            m.cod_mon_bco_central,
                            '6100') moneda,
                     decode(substr(r.cod_rub_padre, 1, 5),
                            '22010',
                            rpad(to_char(r.cod_rub_padre), 10, '0'),
                            decode(substr(r.cod_rub_padre, 1, 5),
                                   '14010',
                                   rpad(to_char(r.cod_rub_padre), 10, '0'),
                                   decode(substr(r.cod_rub_padre, 1, 10),
                                          '12010123060',
                                          '12010123006',
                                          decode(substr(r.cod_rub_padre, 1, 10),
                                                 '12010123080',
                                                 '12010123008',
                                                 rpad(to_char(r.cod_rub_padre),
                                                      10,
                                                      '0'))))) cuentas,
                     (case
                       when c.cod_moneda not in (v_mon_local, v_mon_fuerte) then
                        FUB_CON_MON_A_MONEDA(c.cod_moneda,
                                             v_mon_fuerte,
                                             case
                                               when c.tip_saldo = 'V' then
                                                sal_actual * -1
                                               else
                                                sal_actual
                                             end)
                       else
                        (case
                          when c.tip_saldo = 'V' then
                           sal_actual * -1
                          else
                           sal_actual
                        end)
                     end) monto,
                     (decode(c.cod_moneda,
                             v_mon_local,
                             d.sal_actual,
                             pag_gen.fu_obt_cotizacion(c.cod_moneda,
                                                       v_fec_proceso) *
                             d.sal_actual)) monto_gs,
                     d.nro_cuenta cuenta,
                     (CASE
                       WHEN pr.cod_modalidad IN (675, 677) THEN
                        1
                       ELSE
                        (nvl(pr.fec_vencimiento, v_fec_proceso) -
                        v_fec_proceso)
                     END) dias
                FROM cb_sal_inventarios_det     d,
                     cb_sal_inventarios         c,
                     cb_rubros                  r,
                     ba_monedas                 m,
                     ge_clientes                g,
                     ge_cta_clientes            ge,
                     pr_cta_prestamos           pr
               WHERE c.nro_referencia = d.nro_referencia
                 AND c.cod_rubro = r.cod_rubro
                 AND c.cod_moneda = m.cod_moneda
                 AND c.cod_modulo = 6
                 AND c.tip_saldo = 'V' -- Previsiones
                 AND ge.nro_cuenta = d.nro_cuenta
                 AND g.cod_persona = ge.cod_persona
                 AND ge.relacion = 'P'
                 AND nvl(d.sal_actual, 0) != 0
                 AND c.cod_rubro IS NOT NULL
                 AND d.nro_cuenta = pr.nro_cuenta
                 AND pr.estado != 'N') v
       GROUP BY v.moneda,
                v.cuentas,
                (CASE
                  WHEN cuentas like '16%' THEN
                   '10'
                  WHEN dias <= 0 OR dias = 1 THEN
                   '11'
                  WHEN dias = 2 THEN
                   '12'
                  WHEN dias = 3 THEN
                   '13'
                  WHEN dias = 4 THEN
                   '14'
                  WHEN dias = 5 THEN
                   '15'
                  WHEN dias BETWEEN 6 AND 15 THEN
                   '20'
                  WHEN dias BETWEEN 16 AND 30 THEN
                   '30'
                  WHEN dias BETWEEN 31 AND 60 THEN
                   '40'
                  WHEN dias BETWEEN 61 AND 90 THEN
                   '50'
                  WHEN dias BETWEEN 91 AND 180 THEN
                   '60'
                  WHEN dias BETWEEN 181 AND 365 THEN
                   '70'
                  WHEN dias > 365 THEN
                   '80'
                END)
      UNION ALL
      --- Previsiones diferidas
      SELECT v.moneda,
             v.cuentas,
             NVL((CASE
                   WHEN dias <= 0 then
                    '10'
                   WHEN dias = 1 THEN
                    '11'
                   WHEN dias = 2 THEN
                    '12'
                   WHEN dias = 3 THEN
                    '13'
                   WHEN dias = 4 THEN
                    '14'
                   WHEN dias = 5 THEN
                    '15'
                   WHEN dias BETWEEN 6 AND 15 THEN
                    '20'
                   WHEN dias BETWEEN 16 AND 30 THEN
                    '30'
                   WHEN dias BETWEEN 31 AND 60 THEN
                    '40'
                   WHEN dias BETWEEN 61 AND 90 THEN
                    '50'
                   WHEN dias BETWEEN 91 AND 180 THEN
                    '60'
                   WHEN dias BETWEEN 181 AND 365 THEN
                    '70'
                   WHEN dias > 365 THEN
                    '80'
                 END),
                 '10') plazo,
             nvl(SUM(v.monto), 0) monto
        FROM (SELECT decode(c.cod_moneda,
                            'GS',
                            m.cod_mon_bco_central,
                            '6100') moneda,
                     decode(substr(r.cod_rub_padre, 1, 5),
                            '22010',
                            rpad(to_char(r.cod_rub_padre), 10, '0'),
                            decode(substr(r.cod_rub_padre, 1, 5),
                                   '14010',
                                   rpad(to_char(r.cod_rub_padre), 10, '0'),
                                   decode(substr(r.cod_rub_padre, 1, 10),
                                          '12010123060',
                                          '12010123006',
                                          decode(substr(r.cod_rub_padre, 1, 10),
                                                 '12010123080',
                                                 '12010123008',
                                                 rpad(to_char(r.cod_rub_padre),
                                                      10,
                                                      '0'))))) cuentas,
                     (case
                       when c.cod_moneda not in ('GS', 'USD') then
                        decode(substr(r.cod_rub_padre, 9, 2),
                               '99',
                               FUB_CON_MON_A_MONEDA(c.cod_moneda,
                                                    'USD',
                                                    d.sal_actual * -1),
                               FUB_CON_MON_A_MONEDA(c.cod_moneda,
                                                    'USD',
                                                    d.sal_actual))
                       else
                        decode(substr(r.cod_rub_padre, 9, 2),
                               '99',
                               d.sal_actual * -1,
                               d.sal_actual)
                     end) monto,
                     d.nro_cuenta cuenta,
                     (case
                       when pr.cod_modalidad in (675, 677) then
                        1
                       else
                        (nvl(pr.fec_vencimiento, v_fec_proceso) -
                        v_fec_proceso)
                     end) dias
                FROM cb_sal_inventarios_det     d,
                     cb_sal_inventarios         c,
                     pr_cta_prestamos           pr,
                     cb_rubros                  r,
                     ba_monedas                 m
               WHERE c.nro_referencia = d.nro_referencia
                 and c.cod_rubro = r.cod_rubro
                 AND c.cod_moneda = m.cod_moneda
                 and d.nro_cuenta = pr.nro_cuenta
                 AND c.cod_modulo = 6
                 AND c.tip_saldo = 'O') v
       GROUP BY v.moneda,
                v.cuentas,
                (CASE
                  WHEN dias <= 0 then
                   '10'
                  WHEN dias = 1 THEN
                   '11'
                  WHEN dias = 2 THEN
                   '12'
                  WHEN dias = 3 THEN
                   '13'
                  WHEN dias = 4 THEN
                   '14'
                  WHEN dias = 5 THEN
                   '15'
                  WHEN dias BETWEEN 6 AND 15 THEN
                   '20'
                  WHEN dias BETWEEN 16 AND 30 THEN
                   '30'
                  WHEN dias BETWEEN 31 AND 60 THEN
                   '40'
                  WHEN dias BETWEEN 61 AND 90 THEN
                   '50'
                  WHEN dias BETWEEN 91 AND 180 THEN
                   '60'
                  WHEN dias BETWEEN 181 AND 365 THEN
                   '70'
                  WHEN dias > 365 THEN
                   '80'
                END)
      UNION ALL
      --CTA.CTE--
      SELECT v.moneda,
             v.cuentas cuentas,
             '10' plazo,
             nvl(SUM(v.monto), 0) monto
        FROM (SELECT decode(c.cod_moneda,
                            v_mon_local,
                            m.cod_mon_bco_central,
                            '6100') moneda,
                     decode(substr(r.cod_rub_padre, 1, 5),
                            '22010',
                            rpad(to_char(r.cod_rub_padre), 10, '0'),
                            decode(substr(r.cod_rub_padre, 1, 5),
                                   '14010',
                                   rpad(to_char(r.cod_rub_padre), 10, '0'),
                                   decode(substr(r.cod_rub_padre, 1, 10),
                                          '12010123060',
                                          '12010123006',
                                          decode(substr(r.cod_rub_padre, 1, 10),
                                                 '12010123080',
                                                 '12010123008',
                                                 rpad(to_char(r.cod_rub_padre),
                                                      10,
                                                      '0'))))) cuentas,
                     (case
                       when c.cod_moneda not in (v_mon_local, v_mon_fuerte) then
                        FUB_CON_MON_A_MONEDA(c.cod_moneda,
                                             v_mon_fuerte,
                                             case
                                               when c.tip_saldo = 'V' then
                                                sal_actual * -1
                                               else
                                                sal_actual
                                             end)
                       else
                        (case
                          when c.tip_saldo = 'V' then
                           sal_actual * -1
                          else
                           sal_actual
                        end)
                     end) monto,
                     d.nro_cuenta cuenta
                FROM cb_sal_inventarios_det     d,
                     cb_sal_inventarios         c,
                     cb_rubros                  r,
                     ba_monedas                 m,
                     ge_clientes                g,
                     ge_cta_clientes            ge
               WHERE c.nro_referencia = d.nro_referencia
                 AND c.cod_rubro = r.cod_rubro
                 AND c.cod_moneda = m.cod_moneda
                 AND c.cod_modulo = 4
                 AND c.cod_modalidad = 41
                 AND c.tip_saldo in ('C', 'T', 'V')
                 AND nvl(d.sal_actual, 0) != 0
                    --AND substr(r.cod_rub_padre,1,2) <> '16'
                 AND c.cod_rubro IS NOT NULL
                 AND ge.nro_cuenta = d.nro_cuenta
                 AND g.cod_persona = ge.cod_persona
                 AND ge.relacion = 'P') v
       GROUP BY v.moneda, v.cuentas
      UNION ALL
      --AHORRO
      SELECT v.moneda, v.cuentas,v.plazo,nvl(SUM(v.monto),0) monto
        FROM (SELECT decode(c.cod_moneda, v_mon_local, m.cod_mon_bco_central,'6100') moneda,
                decode(substr(r.cod_rub_padre, 1, 5), '22010', rpad(to_char(r.cod_rub_padre), 10, '0') ,
                        decode(substr(r.cod_rub_padre, 1, 5), '14010', rpad(to_char(r.cod_rub_padre), 10, '0') ,
                        decode(substr(r.cod_rub_padre, 1, 10), '12010123060', '12010123006',
                        decode(substr(r.cod_rub_padre, 1, 10), '12010123080', '12010123008',
                        rpad(to_char(r.cod_rub_padre), 10, '0') ))))  cuentas,
                         '10' plazo,
                         (case when c.cod_moneda not in (v_mon_local, v_mon_fuerte) then
                               FUB_CON_MON_A_MONEDA(c.cod_moneda,v_mon_fuerte,
                                                    (case when c.tip_saldo in ('A','L','V') then d.sal_actual*-1 else d.sal_actual end))
                          else (case when c.tip_saldo in ('A','L','V') then d.sal_actual*-1 else d.sal_actual end) end) monto,
                         d.nro_cuenta cuenta
           FROM cb_sal_inventarios_det     d,
                cb_sal_inventarios         c,
                cb_rubros                  r,
                ba_monedas                 m,
                ge_clientes                g,
                ge_cta_clientes            ge
          WHERE c.nro_referencia = d.nro_referencia
            AND c.cod_rubro = r.cod_rubro
            AND c.cod_moneda = m.cod_moneda
            AND c.cod_modulo = 3
            AND c.cod_modalidad in (31,334)
            AND c.tip_saldo not in ('R','P','K','H')
            AND nvl(d.sal_actual, 0) != 0
            AND c.cod_rubro IS NOT NULL
            AND ge.nro_cuenta = d.nro_cuenta
            AND g.cod_persona = ge.cod_persona
            AND ge.relacion = 'P') v
  GROUP BY v.moneda, v.cuentas, v.plazo
      UNION
      --OPERACIONES VENCIDAS.
      SELECT v.moneda, v.cuentas, v.plazo, nvl(SUM(v.monto), 0) monto
        FROM (SELECT decode(c.cod_moneda,
                            v_mon_local,
                            m.cod_mon_bco_central,
                            '6100') moneda,
                     decode(substr(r.cod_rub_padre, 1, 5),
                            '22010',
                            rpad(to_char(r.cod_rub_padre), 10, '0'),
                            decode(substr(r.cod_rub_padre, 1, 5),
                                   '14010',
                                   rpad(to_char(r.cod_rub_padre), 10, '0'),
                                   decode(substr(r.cod_rub_padre, 1, 10),
                                          '12010123060',
                                          '12010123006',
                                          decode(substr(r.cod_rub_padre, 1, 10),
                                                 '12010123080',
                                                 '12010123008',
                                                 rpad(to_char(r.cod_rub_padre),
                                                      10,
                                                      '0'))))) cuentas,
                     '10' plazo,
                     (CASE
                       WHEN c.cod_moneda NOT IN (v_mon_local, v_mon_fuerte) THEN
                        fub_con_mon_a_moneda(c.cod_moneda,
                                             v_mon_fuerte,
                                             d.sal_actual)
                       ELSE
                        d.sal_actual
                     END) monto,
                     decode(c.cod_moneda,
                            v_mon_local,
                            d.sal_actual,
                            pag_gen.fu_obt_cotizacion(c.cod_moneda,
                                                      v_fec_proceso) *
                            d.sal_actual) monto_gs,
                     d.nro_cuenta cuenta
                FROM cb_sal_inventarios_det     d,
                     cb_sal_inventarios         c,
                     cb_rubros                  r,
                     ba_monedas                 m
               WHERE d.nro_referencia = c.nro_referencia
                 AND c.cod_rubro = r.cod_rubro
                 AND c.cod_moneda = m.cod_moneda
                 AND c.cod_modulo = 15
                 AND c.tip_saldo = 'C'
                 AND nvl(d.sal_actual, 0) != 0
                 AND c.cod_rubro IS NOT NULL) v
       GROUP BY v.moneda, v.cuentas, v.plazo
      UNION
      --C.D.A
      SELECT v.moneda,
             v.cuentas cuentas,
             (CASE
               WHEN decode(a.est_batch,
                           'B',
                           decode(a.est_cer_batch, 'V', 'V', 'N'),
                           decode(a.est_batch, 'P', 'V', a.est_batch)) = 'V' THEN
                '10'
               WHEN a.fec_vencimiento - v_fec_proceso = 1 THEN
                '11'
               WHEN a.fec_vencimiento - v_fec_proceso = 2 THEN
                '12'
               WHEN a.fec_vencimiento - v_fec_proceso = 3 THEN
                '13'
               WHEN a.fec_vencimiento - v_fec_proceso = 4 THEN
                '14'
               WHEN a.fec_vencimiento - v_fec_proceso = 5 THEN
                '15'
               WHEN a.fec_vencimiento - v_fec_proceso BETWEEN 6 AND 15 THEN
                '20'
               WHEN a.fec_vencimiento - v_fec_proceso BETWEEN 16 AND 30 THEN
                '30'
               WHEN a.fec_vencimiento - v_fec_proceso BETWEEN 31 AND 60 THEN
                '40'
               WHEN a.fec_vencimiento - v_fec_proceso BETWEEN 61 AND 90 THEN
                '50'
               WHEN a.fec_vencimiento - v_fec_proceso BETWEEN 91 AND 180 THEN
                '60'
               WHEN a.fec_vencimiento - v_fec_proceso BETWEEN 181 AND 365 THEN
                '70'
               WHEN a.fec_vencimiento - v_fec_proceso > 365 THEN
                '80'
             END) plazo,
             SUM(v.monto) monto
        FROM (SELECT decode(c.cod_moneda,
                            v_mon_local,
                            m.cod_mon_bco_central,
                            '6100') moneda,
                     decode(substr(r.cod_rub_padre, 1, 5),
                            '22010',
                            rpad(to_char(r.cod_rub_padre), 10, '0'),
                            decode(substr(r.cod_rub_padre, 1, 5),
                                   '14010',
                                   rpad(to_char(r.cod_rub_padre), 10, '0'),
                                   decode(substr(r.cod_rub_padre, 1, 10),
                                          '12010123060',
                                          '12010123006',
                                          decode(substr(r.cod_rub_padre, 1, 10),
                                                 '12010123080',
                                                 '12010123008',
                                                 rpad(to_char(r.cod_rub_padre),
                                                      10,
                                                      '0'))))) cuentas,
                     (case
                       when c.cod_moneda not in (v_mon_local, v_mon_fuerte) then
                        FUB_CON_MON_A_MONEDA(c.cod_moneda,
                                             v_mon_fuerte,
                                             case
                                               when c.tip_saldo = 'A' then
                                                sal_actual * -1
                                               else
                                                sal_actual
                                             end)
                       else
                        (case
                          when c.tip_saldo = 'A' then
                           sal_actual * -1
                          else
                           sal_actual
                        end)
                     end) monto,
                     decode(c.cod_moneda,
                            v_mon_local,
                            d.sal_actual,
                            pag_gen.fu_obt_cotizacion(c.cod_moneda,
                                                      v_fec_proceso) *
                            d.sal_actual) monto_gs,
                     d.nro_cuenta cuenta
                FROM cb_sal_inventarios_det     d,
                     cb_sal_inventarios         c,
                     cb_rubros                  r,
                     ba_monedas                 m,
                     ge_clientes                g,
                     ge_cta_clientes            ge
               WHERE d.nro_referencia = c.nro_referencia
                 AND c.cod_rubro = r.cod_rubro
                 AND c.cod_moneda = m.cod_moneda
                 AND c.cod_modulo = 3
                 AND c.cod_modalidad NOT IN (31, 36, 38, 39, 334)
                 AND c.tip_saldo IN ('C', 'T', 'I', 'A')
                 AND c.situacion NOT IN ('V', 'P') --Vencido - Pend.Cancelacion
                 AND ge.nro_cuenta = d.nro_cuenta
                 AND g.cod_persona = ge.cod_persona
                 AND nvl(d.sal_actual, 0) != 0
                 AND ge.relacion = 'P'
                 AND c.cod_rubro IS NOT NULL) v,
             ah_cta_certificados a
       WHERE v.cuenta = a.nro_cuenta
       GROUP BY v.moneda,
                v.cuentas,
                (CASE
                  WHEN decode(a.est_batch,
                              'B',
                              decode(a.est_cer_batch, 'V', 'V', 'N'),
                              decode(a.est_batch, 'P', 'V', a.est_batch)) = 'V' THEN
                   '10'
                  WHEN a.fec_vencimiento - v_fec_proceso = 1 THEN
                   '11'
                  WHEN a.fec_vencimiento - v_fec_proceso = 2 THEN
                   '12'
                  WHEN a.fec_vencimiento - v_fec_proceso = 3 THEN
                   '13'
                  WHEN a.fec_vencimiento - v_fec_proceso = 4 THEN
                   '14'
                  WHEN a.fec_vencimiento - v_fec_proceso = 5 THEN
                   '15'
                  WHEN a.fec_vencimiento - v_fec_proceso BETWEEN 6 AND 15 THEN
                   '20'
                  WHEN a.fec_vencimiento - v_fec_proceso BETWEEN 16 AND 30 THEN
                   '30'
                  WHEN a.fec_vencimiento - v_fec_proceso BETWEEN 31 AND 60 THEN
                   '40'
                  WHEN a.fec_vencimiento - v_fec_proceso BETWEEN 61 AND 90 THEN
                   '50'
                  WHEN a.fec_vencimiento - v_fec_proceso BETWEEN 91 AND 180 THEN
                   '60'
                  WHEN a.fec_vencimiento - v_fec_proceso BETWEEN 181 AND 365 THEN
                   '70'
                  WHEN a.fec_vencimiento - v_fec_proceso > 365 THEN
                   '80'
                END)
      UNION
      --CDA VENCIDOS
      SELECT v.moneda, v.cuentas cuentas, '10' plazo, SUM(v.monto) monto
        FROM (SELECT decode(c.cod_moneda,
                            v_mon_local,
                            m.cod_mon_bco_central,
                            '6100') moneda,
                     decode(substr(r.cod_rub_padre, 1, 5),
                            '22010',
                            rpad(to_char(r.cod_rub_padre), 10, '0'),
                            decode(substr(r.cod_rub_padre, 1, 5),
                                   '14010',
                                   rpad(to_char(r.cod_rub_padre), 10, '0'),
                                   decode(substr(r.cod_rub_padre, 1, 10),
                                          '12010123060',
                                          '12010123006',
                                          decode(substr(r.cod_rub_padre, 1, 10),
                                                 '12010123080',
                                                 '12010123008',
                                                 rpad(to_char(r.cod_rub_padre),
                                                      10,
                                                      '0'))))) cuentas,
                     (CASE
                       WHEN c.cod_moneda NOT IN (v_mon_local, v_mon_fuerte) THEN
                        fub_con_mon_a_moneda(c.cod_moneda,
                                             v_mon_fuerte,
                                             d.sal_actual)
                       ELSE
                        d.sal_actual
                     END) monto,
                     decode(c.cod_moneda,
                            v_mon_local,
                            d.sal_actual,
                            pag_gen.fu_obt_cotizacion(c.cod_moneda,
                                                      v_fec_proceso) *
                            d.sal_actual) monto_gs,
                     d.nro_cuenta cuenta
                FROM cb_sal_inventarios_det     d,
                     cb_sal_inventarios         c,
                     cb_rubros                  r,
                     ba_monedas                 m,
                     ge_clientes                g,
                     ge_cta_clientes            ge
               WHERE d.nro_referencia = c.nro_referencia
                 AND c.cod_rubro = r.cod_rubro
                 AND c.cod_moneda = m.cod_moneda
                 AND c.cod_modulo = 3
                 AND c.cod_modalidad NOT IN (31, 36, 38, 39, 334)
                 AND c.tip_saldo IN ('C', 'T')
                 AND c.situacion IN ('V', 'P') --Vencido - Pend.Cancelacion
                 AND ge.nro_cuenta = d.nro_cuenta
                 AND g.cod_persona = ge.cod_persona
                 AND nvl(d.sal_actual, 0) != 0
                 AND ge.relacion = 'P'
                 AND c.cod_rubro IS NOT NULL) v,
             ah_cta_certificados a
       WHERE v.cuenta = a.nro_cuenta
       GROUP BY v.moneda, v.cuentas, '10'
      UNION ALL
      --PIGNORACION.
      SELECT v.moneda,
             v.cuentas cuentas,
             NVL((CASE
                   WHEN v.dias <= 0 THEN
                    '10'
                   WHEN v.dias = 1 THEN
                    '11'
                   WHEN v.dias = 2 THEN
                    '12'
                   WHEN v.dias = 3 THEN
                    '13'
                   WHEN v.dias = 4 THEN
                    '14'
                   WHEN v.dias = 5 THEN
                    '15'
                   WHEN v.dias BETWEEN 6 AND 15 THEN
                    '20'
                   WHEN v.dias BETWEEN 16 AND 30 THEN
                    '30'
                   WHEN v.dias BETWEEN 31 AND 60 THEN
                    '40'
                   WHEN v.dias BETWEEN 61 AND 90 THEN
                    '50'
                   WHEN v.dias BETWEEN 91 AND 180 THEN
                    '60'
                   WHEN v.dias BETWEEN 181 AND 365 THEN
                    '70'
                   WHEN v.dias > 365 THEN
                    '80'
                 END),
                 '10') plazo,
             SUM(v.monto) monto
        FROM (SELECT decode(c.cod_moneda,
                            v_mon_local,
                            m.cod_mon_bco_central,
                            '6100') moneda,
                     decode(substr(r.cod_rub_padre, 1, 5),
                            '22010',
                            rpad(to_char(r.cod_rub_padre), 10, '0'),
                            decode(substr(r.cod_rub_padre, 1, 5),
                                   '14010',
                                   rpad(to_char(r.cod_rub_padre), 10, '0'),
                                   decode(substr(r.cod_rub_padre, 1, 10),
                                          '12010123060',
                                          '12010123006',
                                          decode(substr(r.cod_rub_padre, 1, 10),
                                                 '12010123080',
                                                 '12010123008',
                                                 rpad(to_char(r.cod_rub_padre),
                                                      10,
                                                      '0'))))) cuentas,
                     (case
                       when c.cod_moneda not in (v_mon_local, v_mon_fuerte) then
                        FUB_CON_MON_A_MONEDA(c.cod_moneda,
                                             v_mon_fuerte,
                                             d.sal_actual)
                       else
                        d.sal_actual
                     end) monto,
                     d.nro_cuenta cuenta,
                     p.fec_vencimiento - v_fec_proceso dias
                FROM cb_sal_inventarios_det     d,
                     cb_sal_inventarios         c,
                     cb_rubros                  r,
                     ba_monedas                 m,
                     ge_clientes                g,
                     ge_cta_clientes            ge,
                     pr_gar_cash                P
               WHERE c.nro_referencia = d.nro_referencia
                 AND c.cod_rubro = r.cod_rubro
                 AND c.cod_moneda = m.cod_moneda
                 AND c.cod_modulo in (3, 4) --Ahorros y Cta.Cte
                 AND c.cod_modalidad in (31, 41, 334)
                 AND c.tip_saldo = 'P'
                 AND nvl(d.sal_actual, 0) != 0                  
                 AND c.cod_rubro IS NOT NULL
                 AND ge.nro_cuenta = d.nro_cuenta
                 AND g.cod_persona = ge.cod_persona
                 AND ge.relacion = 'P'
                 AND d.nro_cuenta = p.nro_cta_referencia) v
       GROUP BY v.moneda,
                v.cuentas,
                (CASE
                  WHEN v.dias <= 0 THEN
                   '10'
                  WHEN v.dias = 1 THEN
                   '11'
                  WHEN v.dias = 2 THEN
                   '12'
                  WHEN v.dias = 3 THEN
                   '13'
                  WHEN v.dias = 4 THEN
                   '14'
                  WHEN v.dias = 5 THEN
                   '15'
                  WHEN v.dias BETWEEN 6 AND 15 THEN
                   '20'
                  WHEN v.dias BETWEEN 16 AND 30 THEN
                   '30'
                  WHEN v.dias BETWEEN 31 AND 60 THEN
                   '40'
                  WHEN v.dias BETWEEN 61 AND 90 THEN
                   '50'
                  WHEN v.dias BETWEEN 91 AND 180 THEN
                   '60'
                  WHEN v.dias BETWEEN 181 AND 365 THEN
                   '70'
                  WHEN v.dias > 365 THEN
                   '80'
                END)
      UNION ALL
      --- MESA DE DINERO
      SELECT v.moneda,
             v.cuentas,
             (CASE
               WHEN v.dias <= 0 THEN
                '10'
               WHEN v.dias = 1 THEN
                '11'
               WHEN v.dias = 2 THEN
                '12'
               WHEN v.dias = 3 THEN
                '13'
               WHEN v.dias = 4 THEN
                '14'
               WHEN v.dias = 5 THEN
                '15'
               WHEN v.dias BETWEEN 6 AND 15 THEN
                '20'
               WHEN v.dias BETWEEN 16 AND 30 THEN
                '30'
               WHEN v.dias BETWEEN 31 AND 60 THEN
                '40'
               WHEN v.dias BETWEEN 61 AND 90 THEN
                '50'
               WHEN v.dias BETWEEN 91 AND 180 THEN
                '60'
               WHEN v.dias BETWEEN 181 AND 365 THEN
                '70'
               WHEN v.dias > 365 THEN
                '80'
             END) plazo,
             nvl(SUM(v.monto), 0) monto
        FROM (SELECT decode(c.cod_moneda,
                            v_mon_local,
                            m.cod_mon_bco_central,
                            '6100') moneda,
                     decode(substr(r.cod_rub_padre, 1, 5),
                            '22010',
                            rpad(to_char(r.cod_rub_padre), 10, '0'),
                            decode(substr(r.cod_rub_padre, 1, 5),
                                   '14010',
                                   rpad(to_char(r.cod_rub_padre), 10, '0'),
                                   decode(substr(r.cod_rub_padre, 1, 10),
                                          '12010123060',
                                          '12010123006',
                                          decode(substr(r.cod_rub_padre, 1, 10),
                                                 '12010123080',
                                                 '12010123008',
                                                 rpad(to_char(r.cod_rub_padre),
                                                      10,
                                                      '0'))))) cuentas,
                     (case
                       when c.cod_moneda not in (v_mon_local, v_mon_fuerte) then
                        FUB_CON_MON_A_MONEDA(c.cod_moneda,
                                             v_mon_fuerte,
                                             case
                                               when c.tip_saldo = 'A' then
                                                sal_actual * -1
                                               else
                                                sal_actual
                                             end)
                       else
                        (case
                          when c.tip_saldo = 'A' then
                           sal_actual * -1
                          else
                           sal_actual
                        end)
                     end) monto,
                     d.nro_cuenta cuenta,
                     a.fec_vencimiento - v_fec_proceso dias
                FROM cb_sal_inventarios_det     d,
                     cb_sal_inventarios         c,
                     cb_rubros                  r,
                     ba_monedas                 m,
                     ge_clientes                g,
                     ge_cta_clientes            ge,
                     md_cta_documentos          a
               WHERE c.nro_referencia = d.nro_referencia
                 AND c.cod_rubro = r.cod_rubro
                 AND c.cod_moneda = m.cod_moneda
                 AND c.cod_modalidad in (112, 117, 118, 144, 126, 101, 145, 150, 155, 114, 116,106,123)
                 AND c.tip_saldo in ('C', 'A', 'I','D') -- Capital, A devengar e Interés
                 AND ge.nro_cuenta = d.nro_cuenta
                 AND g.cod_persona = ge.cod_persona
                 AND nvl(d.sal_actual, 0) != 0
                 AND ge.relacion = 'P'
                 AND c.cod_rubro IS NOT NULL
                 AND d.nro_cuenta = a.nro_cuenta) v
       GROUP BY v.moneda,
                v.cuentas,
                (CASE
                  WHEN v.dias <= 0 THEN
                   '10'
                  WHEN v.dias = 1 THEN
                   '11'
                  WHEN v.dias = 2 THEN
                   '12'
                  WHEN v.dias = 3 THEN
                   '13'
                  WHEN v.dias = 4 THEN
                   '14'
                  WHEN v.dias = 5 THEN
                   '15'
                  WHEN v.dias BETWEEN 6 AND 15 THEN
                   '20'
                  WHEN v.dias BETWEEN 16 AND 30 THEN
                   '30'
                  WHEN v.dias BETWEEN 31 AND 60 THEN
                   '40'
                  WHEN v.dias BETWEEN 61 AND 90 THEN
                   '50'
                  WHEN v.dias BETWEEN 91 AND 180 THEN
                   '60'
                  WHEN v.dias BETWEEN 181 AND 365 THEN
                   '70'
                  WHEN v.dias > 365 THEN
                   '80'
                END)
      UNION ALL
      --- AHORRO PROGRAMADO
      SELECT v.moneda,
             v.cuentas,
             (CASE
               WHEN v.dias <= 1 THEN
                '11'
               WHEN v.dias = 2 THEN
                '12'
               WHEN v.dias = 3 THEN
                '13'
               WHEN v.dias = 4 THEN
                '14'
               WHEN v.dias = 5 THEN
                '15'
               WHEN v.dias BETWEEN 6 AND 15 THEN
                '20'
               WHEN v.dias BETWEEN 16 AND 30 THEN
                '30'
               WHEN v.dias BETWEEN 31 AND 60 THEN
                '40'
               WHEN v.dias BETWEEN 61 AND 90 THEN
                '50'
               WHEN v.dias BETWEEN 91 AND 180 THEN
                '60'
               WHEN v.dias BETWEEN 181 AND 365 THEN
                '70'
               WHEN v.dias > 365 THEN
                '80'
             END)     plazo,
             nvl(SUM(v.monto), 0) monto
        FROM (SELECT decode(c.cod_moneda,
                            v_mon_local,
                            m.cod_mon_bco_central,
                            '6100') moneda,
                     decode(substr(r.cod_rub_padre, 1, 5),
                            '22010',
                            rpad(to_char(r.cod_rub_padre), 10, '0'),
                            decode(substr(r.cod_rub_padre, 1, 5),
                                   '14010',
                                   rpad(to_char(r.cod_rub_padre), 10, '0'),
                                   decode(substr(r.cod_rub_padre, 1, 10),
                                          '12010123060',
                                          '12010123006',
                                          decode(substr(r.cod_rub_padre, 1, 10),
                                                 '12010123080',
                                                 '12010123008',
                                                 rpad(to_char(r.cod_rub_padre),
                                                      10,
                                                      '0'))))) cuentas,
                     (case
                       when c.cod_moneda not in (v_mon_local, v_mon_fuerte) then
                        FUB_CON_MON_A_MONEDA(c.cod_moneda,
                                             v_mon_fuerte,
                                             sal_actual)
                       else
                        sal_actual
                     end) monto,
                     d.nro_cuenta cuenta,
                     a.fec_vencimiento - v_fec_proceso dias
                FROM cb_sal_inventarios_det     d,
                     cb_sal_inventarios         c,
                     cb_rubros                  r,
                     ba_monedas                 m,
                     ge_clientes                g,
                     ge_cta_clientes            ge,
                     ah_cta_plazos          a
               WHERE c.nro_referencia = d.nro_referencia
                 AND c.cod_rubro = r.cod_rubro
                 AND c.cod_moneda = m.cod_moneda
                 AND c.tip_saldo in ('C') -- Capital
                 AND ge.nro_cuenta = d.nro_cuenta
                 AND g.cod_persona = ge.cod_persona
                 AND nvl(d.sal_actual, 0) != 0
                 AND ge.relacion = 'P'
                 AND c.cod_rubro IS NOT NULL
                 AND d.nro_cuenta = a.nro_cuenta) v
       GROUP BY v.moneda,
                v.cuentas,
                (CASE
                  WHEN v.dias <= 1 THEN
                   '11'
                  WHEN v.dias = 2 THEN
                   '12'
                  WHEN v.dias = 3 THEN
                   '13'
                  WHEN v.dias = 4 THEN
                   '14'
                  WHEN v.dias = 5 THEN
                   '15'
                  WHEN v.dias BETWEEN 6 AND 15 THEN
                   '20'
                  WHEN v.dias BETWEEN 16 AND 30 THEN
                   '30'
                  WHEN v.dias BETWEEN 31 AND 60 THEN
                   '40'
                  WHEN v.dias BETWEEN 61 AND 90 THEN
                   '50'
                  WHEN v.dias BETWEEN 91 AND 180 THEN
                   '60'
                  WHEN v.dias BETWEEN 181 AND 365 THEN
                   '70'
                  WHEN v.dias > 365 THEN
                   '80'
                END)
      UNION ALL
       --BONOS SUBORDINADOS
      SELECT v.moneda,
             v.cuentas,
             (CASE
               WHEN v.dias <= 0 THEN
                '10'
               WHEN v.dias = 1 THEN
                '11'
               WHEN v.dias = 2 THEN
                '12'
               WHEN v.dias = 3 THEN
                '13'
               WHEN v.dias = 4 THEN
                '14'
               WHEN v.dias = 5 THEN
                '15'
               WHEN v.dias BETWEEN 6 AND 15 THEN
                '20'
               WHEN v.dias BETWEEN 16 AND 30 THEN
                '30'
               WHEN v.dias BETWEEN 31 AND 60 THEN
                '40'
               WHEN v.dias BETWEEN 61 AND 90 THEN
                '50'
               WHEN v.dias BETWEEN 91 AND 180 THEN
                '60'
               WHEN v.dias BETWEEN 181 AND 365 THEN
                '70'
               WHEN v.dias > 365 THEN
                '80'
             END)     plazo,
             nvl(SUM(v.monto), 0) monto
        FROM (SELECT decode(c.cod_moneda,
                            v_mon_local,
                            m.cod_mon_bco_central,
                            '6100') moneda,
                     decode(substr(r.cod_rub_padre, 1, 5),
                            '22010',
                            rpad(to_char(r.cod_rub_padre), 10, '0'),
                            decode(substr(r.cod_rub_padre, 1, 5),
                                   '14010',
                                   rpad(to_char(r.cod_rub_padre), 10, '0'),
                                   decode(substr(r.cod_rub_padre, 1, 10),
                                          '12010123060',
                                          '12010123006',
                                          decode(substr(r.cod_rub_padre, 1, 10),
                                                 '12010123080',
                                                 '12010123008',
                                                 rpad(to_char(r.cod_rub_padre),
                                                      10,
                                                      '0'))))) cuentas,
                     (case
                       when c.cod_moneda not in (v_mon_local, v_mon_fuerte) then
                        FUB_CON_MON_A_MONEDA(c.cod_moneda,
                                             v_mon_fuerte,
                                             case
                                               when c.tip_saldo = 'A' then
                                                sal_actual * -1
                                               else
                                                sal_actual
                                             end)
                       else
                        (case
                          when c.tip_saldo = 'A' then
                           sal_actual * -1
                          else
                           sal_actual
                        end)
                     end) monto,
                     d.nro_cuenta cuenta,
                     a.fec_vencimiento - v_fec_proceso dias
                FROM cb_sal_inventarios_det     d,
                     cb_sal_inventarios         c,
                     cb_rubros                  r,
                     ba_monedas                 m,
                     ge_clientes                g,
                     ge_cta_clientes            ge,
                     ah_cta_certificados         a
               WHERE c.nro_referencia = d.nro_referencia
                 AND c.cod_rubro = r.cod_rubro
                 AND c.cod_moneda = m.cod_moneda
                 AND instr(fug_obt_pardinamico('MAD_BON_SUBORDINADOS'), a.cod_modalidad || ',') >0
                 AND c.tip_saldo in ('C','A','I') -- Capital
                 AND ge.nro_cuenta = d.nro_cuenta
                 AND g.cod_persona = ge.cod_persona
                 AND nvl(d.sal_actual, 0) != 0
                 AND ge.relacion = 'P'
                 AND c.cod_rubro IS NOT NULL
                 AND d.nro_cuenta = a.nro_cuenta) v
       GROUP BY v.moneda,
                v.cuentas,
                (CASE
                  WHEN v.dias <= 0 THEN
                   '10'
                  WHEN v.dias = 1 THEN
                   '11'
                  WHEN v.dias = 2 THEN
                   '12'
                  WHEN v.dias = 3 THEN
                   '13'
                  WHEN v.dias = 4 THEN
                   '14'
                  WHEN v.dias = 5 THEN
                   '15'
                  WHEN v.dias BETWEEN 6 AND 15 THEN
                   '20'
                  WHEN v.dias BETWEEN 16 AND 30 THEN
                   '30'
                  WHEN v.dias BETWEEN 31 AND 60 THEN
                   '40'
                  WHEN v.dias BETWEEN 61 AND 90 THEN
                   '50'
                  WHEN v.dias BETWEEN 91 AND 180 THEN
                   '60'
                  WHEN v.dias BETWEEN 181 AND 365 THEN
                   '70'
                  WHEN v.dias > 365 THEN
                   '80'
                END)

      UNION ALL
      --- Tarjetas
      SELECT v.moneda,
             v.cuentas,
             (CASE
               WHEN v.dias <= 0 THEN
                '10'
               WHEN v.dias = 1 THEN
                '11'
               WHEN v.dias = 2 THEN
                '12'
               WHEN v.dias = 3 THEN
                '13'
               WHEN v.dias = 4 THEN
                '14'
               WHEN v.dias = 5 THEN
                '15'
               WHEN v.dias BETWEEN 6 AND 15 THEN
                '20'
               WHEN v.dias BETWEEN 16 AND 30 THEN
                '30'
               WHEN v.dias BETWEEN 31 AND 60 THEN
                '40'
               WHEN v.dias BETWEEN 61 AND 90 THEN
                '50'
               WHEN v.dias BETWEEN 91 AND 180 THEN
                '60'
               WHEN v.dias BETWEEN 181 AND 365 THEN
                '70'
               WHEN v.dias > 365 THEN
                '80'
             END) plazo,
             nvl(SUM(v.monto), 0) monto
        FROM (SELECT decode(c.cod_moneda,
                            'GS',
                            m.cod_mon_bco_central,
                            '6100') moneda,
                     decode(substr(r.cod_rub_padre, 1, 5),
                            '22010',
                            rpad(to_char(r.cod_rub_padre), 10, '0'),
                            decode(substr(r.cod_rub_padre, 1, 5),
                                   '14010',
                                   rpad(to_char(r.cod_rub_padre), 10, '0'),
                                   decode(substr(r.cod_rub_padre, 1, 10),
                                          '12010123060',
                                          '12010123006',
                                          decode(substr(r.cod_rub_padre, 1, 10),
                                                 '12010123080',
                                                 '12010123008',
                                                 rpad(to_char(r.cod_rub_padre),
                                                      10,
                                                      '0'))))) cuentas,
                     (case
                       when c.cod_moneda not in (v_mon_local, v_mon_fuerte) then
                        FUB_CON_MON_A_MONEDA(c.cod_moneda,
                                             v_mon_fuerte,
                                             case
                                               when c.tip_saldo = 'V' then
                                                sal_actual * -1
                                               else
                                                sal_actual
                                             end)
                       else
                        (case
                          when c.tip_saldo = 'V' then
                           sal_actual * -1
                          else
                           sal_actual
                        end)
                     end) monto,
                     d.nro_cuenta cuenta,
                     decode(nvl(a.dia_mora, 0),
                            0,
                            a.fec_ult_cierre,
                            pag_cal.fu_obt_fec_actual(2) - a.dia_mora - 1) -
                     v_fec_proceso dias
                FROM cb_sal_inventarios_det     d,
                     cb_sal_inventarios         c,
                     cb_rubros                  r,
                     ba_monedas                 m,
                     ge_clientes                g,
                     ge_cta_clientes            ge,
                     ta_cta_tarjetas            a
               WHERE c.nro_referencia = d.nro_referencia
                 AND c.cod_rubro = r.cod_rubro
                 AND c.cod_moneda = m.cod_moneda
                 AND c.tip_saldo in ('C', 'V') -- Capital y previsiones
                 and substr(r.cod_rub_padre, 1, 2) <> '25' -- Previsiones no se informa
                 AND ge.nro_cuenta = d.nro_cuenta
                 AND g.cod_persona = ge.cod_persona
                 AND nvl(d.sal_actual, 0) != 0
                 AND ge.relacion = 'P'
                 AND c.cod_rubro IS NOT NULL
                 AND d.nro_cuenta = a.nro_cuenta) v
       GROUP BY v.moneda,
                v.cuentas,
                (CASE
                  WHEN v.dias <= 0 THEN
                   '10'
                  WHEN v.dias = 1 THEN
                   '11'
                  WHEN v.dias = 2 THEN
                   '12'
                  WHEN v.dias = 3 THEN
                   '13'
                  WHEN v.dias = 4 THEN
                   '14'
                  WHEN v.dias = 5 THEN
                   '15'
                  WHEN v.dias BETWEEN 6 AND 15 THEN
                   '20'
                  WHEN v.dias BETWEEN 16 AND 30 THEN
                   '30'
                  WHEN v.dias BETWEEN 31 AND 60 THEN
                   '40'
                  WHEN v.dias BETWEEN 61 AND 90 THEN
                   '50'
                  WHEN v.dias BETWEEN 91 AND 180 THEN
                   '60'
                  WHEN v.dias BETWEEN 181 AND 365 THEN
                   '70'
                  WHEN v.dias > 365 THEN
                   '80'
                END);

  BEGIN
    IF p_fecha IS NOT NULL THEN
      v_fec_proceso := p_fecha;
    ELSE
      v_fec_proceso := pag_cal.fu_obt_fec_actual(1);
    END IF;
    ----------------Borra de la tabla los registros ya generados en la fecha------------
    DELETE sb_liq_diarios
     WHERE fecha = v_fec_proceso
       AND tipo = 'I';
    -----------Inserta registros en la tabla sb_liq_diarios----------------
    FOR reg IN c_res_263 LOOP
      IF reg.monto != 0 THEN
        --VERIFICO SI YA SE INSERTO EL REGISTRO.
        SELECT COUNT(1)
          INTO V_CONTROL
          FROM SB_LIQ_DIARIOS H
         WHERE H.FECHA = v_fec_proceso
           AND H.COD_CUENTA = reg.cuentas
           AND H.COD_MONEDA = reg.moneda
           AND H.PLAZO = reg.plazo;

        if v_control > 0 then

          UPDATE SB_LIQ_DIARIOS H
             SET H.IMPORTE = H.IMPORTE + REG.MONTO
           WHERE H.FECHA = v_fec_proceso
             AND H.COD_CUENTA = reg.cuentas
             AND H.COD_MONEDA = reg.moneda
             AND H.PLAZO = reg.plazo;

        else

          INSERT INTO sb_liq_diarios
            (fecha, cod_moneda, cod_cuenta, plazo, importe, tipo)
          VALUES
            (v_fec_proceso,
             reg.moneda,
             reg.cuentas,
             reg.plazo,
             reg.monto,
             'I');

        end if;
      END IF;
    END LOOP;
    UPDATE sb_liq_diarios
       set importe = abs(importe)
     where fecha = v_fec_proceso;

  END;

  --- Circular 263 - Analisis de Liquidez --Cierre Contable - Contabilidad
  --- Circular 263 - Analisis de Liquidez --Cierre Contable - Contabilidad
  PROCEDURE PR_INS_LIQ_DIA_CON(p_fecha IN DATE DEFAULT NULL) IS
    --VARIABLES
    v_cod_grupo      cb_gru_rubros.cod_gru_rubro%TYPE := fug_obt_pardinamico('GRU_RUB_LIQ_DIARIA');
    v_fec_proceso    ge_calendarios.fec_actual%TYPE;
    v_cod_mon_local  ba_monedas.cod_moneda%TYPE := pag_gen.fu_obt_mon_local;
    v_cod_mon_fuerte ba_monedas.cod_moneda%TYPE := pag_gen.fu_obt_mon_fuerte;
    v_importe        sb_liq_diarios.importe%type;
    v_tot_ajustado   sb_liq_diarios.importe%type;
    v_control        sb_liq_diarios.plazo%type;
    v_sal_rubro      sb_liq_diarios.importe%type := 0;
    v_tot_inv_abs    sb_liq_diarios.importe%TYPE;
    v_signo_inv      NUMBER;
    v_bal_abs        sb_liq_diarios.importe%TYPE;
    v_diferencia_abs sb_liq_diarios.importe%TYPE;
    v_sobrante       sb_liq_diarios.importe%TYPE;
    v_monto_recorte  sb_liq_diarios.importe%TYPE;
    v_diferencia     sb_liq_diarios.importe%TYPE;
    v_tot_inv_p10    sb_liq_diarios.importe%TYPE;
    v_tot_inv_otros  sb_liq_diarios.importe%TYPE;

    -- CURSOR SALDOS DE BALANCE (EVALUACIÓN DINÁMICA POR FECHA DE PROCESO)
    CURSOR c_res_263_disponibilidades IS
      -- 1. Moneda Local ('6900')
      SELECT decode(substr(d.cod_rubro, 1, 10),
                    '12010123060', '12010123006',
                    '12010123080', '12010123008',
                    substr(d.cod_rubro, 1, 10)) cod_rubro,
             '6900' moneda,
             ABS(SUM((nvl(sal_mon_loc_ant, 0) + nvl(deb_mon_local, 0) - nvl(cre_mon_local, 0)) -
                 (nvl(sal_equ_loc_ant, 0) + nvl(deb_equ_local, 0) - nvl(cre_equ_local, 0)))) monto_abs,
             naturaleza
        FROM cb_sal_consolidados a, cb_rubros c, cb_gru_rubros_det d
       WHERE a.cod_rubro = c.cod_rubro
         AND a.cod_rubro = d.cod_rubro
         AND d.cod_gru_rubro = v_cod_grupo
         AND d.cod_moneda = v_cod_mon_local
       GROUP BY decode(substr(d.cod_rubro, 1, 10),
                       '12010123060', '12010123006',
                       '12010123080', '12010123008',
                       substr(d.cod_rubro, 1, 10)), naturaleza
      UNION ALL
      -- 2. Moneda Extranjera ('6100')
      SELECT decode(substr(d.cod_rubro, 1, 10),
                    '12010123060', '12010123006',
                    '12010123080', '12010123008',
                    substr(d.cod_rubro, 1, 10)) cod_rubro,
             '6100' moneda,
             ABS(SUM(nvl(a.sal_mon_rub_ant + a.deb_mon_rubro - a.cre_mon_rubro, 0))) monto_abs,
             naturaleza
        FROM cb_sal_consolidados a, cb_rubros c, cb_gru_rubros_det d
       WHERE a.cod_rubro = c.cod_rubro
         AND a.cod_rubro = d.cod_rubro
         AND d.cod_gru_rubro = v_cod_grupo
         AND d.cod_moneda = v_cod_mon_fuerte
       GROUP BY decode(substr(d.cod_rubro, 1, 10),
                       '12010123060', '12010123006',
                       '12010123080', '12010123008',
                       substr(d.cod_rubro, 1, 10)), naturaleza;

    -- CURSOR DE PLAZOS DE INVENTARIO PARA PRORRATEO (DE MAYOR A MENOR PLAZO)
    CURSOR c_plazos_inventario(p_cuenta VARCHAR2, p_moneda VARCHAR2) IS
      SELECT plazo, SUM(importe) total_plazo, SUM(ABS(importe)) total_plazo_abs
        FROM sb_liq_diarios
       WHERE fecha = v_fec_proceso
         AND cod_cuenta = p_cuenta
         AND cod_moneda = p_moneda
         AND tipo = 'I'
       GROUP BY plazo
       ORDER BY TO_NUMBER(plazo) DESC;

  BEGIN
    -- 1. DETERMINACIÓN DE LA FECHA DE PROCESO
    IF p_fecha IS NOT NULL THEN
       v_fec_proceso := p_fecha;
    ELSE
       v_fec_proceso := pag_cal.fu_obt_fec_actual(2);
    END IF;

    -- 2. BORRAR EXCLUSIVAMENTE LOS AJUSTES 'C' PREVIOS
    DELETE FROM sb_liq_diarios
     WHERE fecha = v_fec_proceso
       AND tipo = 'C';

    -- 3. PROCESAMIENTO GENERAL CON CONCILIACIÓN Y PRORRATEO
    FOR reg IN c_res_263_disponibilidades LOOP

       v_bal_abs := reg.monto_abs;

       -- Sumar la masa nominal en valor absoluto del Inventario 'I'
       SELECT NVL(SUM(ABS(h.importe)), 0)
         INTO v_tot_inv_abs
         FROM sb_liq_diarios h
        WHERE h.cod_cuenta = reg.cod_rubro
          AND h.cod_moneda = reg.moneda
          AND h.fecha      = v_fec_proceso
          AND h.tipo       = 'I';

       -- Determinar el signo predominante con el que viene guardado el Inventario 'I'
       SELECT NVL(SIGN(SUM(h.importe)), 1)
         INTO v_signo_inv
         FROM sb_liq_diarios h
        WHERE h.cod_cuenta = reg.cod_rubro
          AND h.cod_moneda = reg.moneda
          AND h.fecha      = v_fec_proceso
          AND h.tipo       = 'I';

       IF v_signo_inv = 0 THEN
          v_signo_inv := 1;
       END IF;

       -- Diferencia entre Masa de Balance y Masa de Inventario
       v_diferencia_abs := v_bal_abs - v_tot_inv_abs;

      -- =========================================================================
       -- ESCENARIO A: BALANCE > INVENTARIO (Falta Saldo -> Asigna a Plazo 10)
       -- =========================================================================
       IF v_diferencia_abs > 0 THEN

          -- Inventario 'I' que pertenece exclusivamente al Plazo 10
          SELECT NVL(SUM(importe), 0)
            INTO v_tot_inv_p10
            FROM sb_liq_diarios
           WHERE fecha      = v_fec_proceso
             AND cod_cuenta = reg.cod_rubro
             AND cod_moneda = reg.moneda
             AND plazo      = '10'
             AND tipo       = 'I';

          -- Masa de Inventario 'I' de los demas plazos en valor absoluto
          SELECT NVL(SUM(ABS(importe)), 0)
            INTO v_tot_inv_otros
            FROM sb_liq_diarios
           WHERE fecha      = v_fec_proceso
             AND cod_cuenta = reg.cod_rubro
             AND cod_moneda = reg.moneda
             AND plazo      <> '10'
             AND tipo       = 'I';

          -- Brecha exacta para que la suma final en ASCII de 100% igual al Balance
          v_diferencia := reg.monto_abs - v_tot_inv_otros - v_tot_inv_p10;

          INSERT INTO sb_liq_diarios (
              fecha, cod_moneda, cod_cuenta, plazo, importe, tipo
          ) VALUES (
              v_fec_proceso,
              reg.moneda,
              reg.cod_rubro,
              '10',
              v_diferencia,
              'C'
          );
       -- =========================================================================
       -- ESCENARIO B: INVENTARIO > BALANCE (Sobra Saldo -> Prorrateo por Plazo)
       -- =========================================================================
       ELSIF v_diferencia_abs < 0 AND v_bal_abs > 0 THEN

          v_sobrante := ABS(v_diferencia_abs);

          FOR p IN c_plazos_inventario(reg.cod_rubro, reg.moneda) LOOP

             IF p.total_plazo_abs <= v_sobrante THEN
                v_monto_recorte := p.total_plazo_abs;
             ELSE
                v_monto_recorte := v_sobrante;
             END IF;

             IF p.total_plazo < 0 THEN
                v_monto_recorte := v_monto_recorte * 1;
             ELSE
                v_monto_recorte := v_monto_recorte * (-1);
             END IF;

             INSERT INTO sb_liq_diarios (
                 fecha, cod_moneda, cod_cuenta, plazo, importe, tipo
             ) VALUES (
                 v_fec_proceso,
                 reg.moneda,
                 reg.cod_rubro,
                 p.plazo,
                 v_monto_recorte,
                 'C'
             );

             v_sobrante := v_sobrante - ABS(v_monto_recorte);
             EXIT WHEN v_sobrante = 0;

          END LOOP;

       END IF;

    END LOOP;

    -- 4. NORMALIZACIÓN DE PLAZOS NULOS
    UPDATE sb_liq_diarios h
       SET h.plazo = '10'
     WHERE h.plazo IS NULL
       AND h.fecha = v_fec_proceso;

    -- 5. DEPURACIONES FINALES
    -- 5.1 Elimina cuentas no parametrizadas
    DELETE FROM sb_liq_diarios a
     WHERE a.fecha = v_fec_proceso
       AND NOT EXISTS (
           SELECT 1
             FROM cb_gru_rubros_det d
            WHERE d.cod_gru_rubro = v_cod_grupo
              AND decode(substr(d.cod_rubro, 1, 10),
                         '12010123060', '12010123006',
                         '12010123080', '12010123008',
                         substr(d.cod_rubro, 1, 10)) = a.cod_cuenta
       );

    -- 5.2 Elimina cuentas incobrables/especiales
    DELETE FROM sb_liq_diarios h
     WHERE h.fecha = v_fec_proceso
       AND h.cod_cuenta LIKE '51%';

    -- 5.3 Limpieza de contrapartidas tipo 'C' en 0
    DELETE FROM sb_liq_diarios h
     WHERE h.fecha = v_fec_proceso
       AND h.tipo = 'C'
       AND h.importe = 0;

    -- 5.4 LIMPIEZA DE CUENTAS CUYO BALANCE ES CERO EN LA FECHA
    DELETE FROM sb_liq_diarios h
     WHERE h.fecha = v_fec_proceso
       AND (h.cod_cuenta, h.cod_moneda) IN (
           -- Moneda Local ('6900')
           SELECT decode(substr(d.cod_rubro, 1, 10),
                         '12010123060', '12010123006',
                         '12010123080', '12010123008',
                         substr(d.cod_rubro, 1, 10)) cod_rubro,
                  '6900' moneda
             FROM cb_sal_consolidados_dia a, cb_rubros c, cb_gru_rubros_det d
            WHERE a.cod_rubro = c.cod_rubro
              AND a.cod_rubro = d.cod_rubro
              AND a.fecha     = v_fec_proceso
              AND d.cod_gru_rubro = v_cod_grupo
              AND d.cod_moneda = v_cod_mon_local
            GROUP BY decode(substr(d.cod_rubro, 1, 10),
                            '12010123060', '12010123006',
                            '12010123080', '12010123008',
                            substr(d.cod_rubro, 1, 10)), naturaleza
           HAVING SUM((nvl(sal_mon_loc_ant, 0) + nvl(deb_mon_local, 0) - nvl(cre_mon_local, 0)) -
                      (nvl(sal_equ_loc_ant, 0) + nvl(deb_equ_local, 0) - nvl(cre_equ_local, 0))) = 0

           UNION ALL

           -- Moneda Extranjera ('6100')
           SELECT decode(substr(d.cod_rubro, 1, 10),
                         '12010123060', '12010123006',
                         '12010123080', '12010123008',
                         substr(d.cod_rubro, 1, 10)) cod_rubro,
                  '6100' moneda
             FROM cb_sal_consolidados_dia a, cb_rubros c, cb_gru_rubros_det d
            WHERE a.cod_rubro = c.cod_rubro
              AND a.cod_rubro = d.cod_rubro
              AND a.fecha     = v_fec_proceso
              AND d.cod_gru_rubro = v_cod_grupo
              AND d.cod_moneda = v_cod_mon_fuerte
            GROUP BY decode(substr(d.cod_rubro, 1, 10),
                            '12010123060', '12010123006',
                            '12010123080', '12010123008',
                            substr(d.cod_rubro, 1, 10)), naturaleza
           HAVING SUM(nvl(a.sal_mon_rub_ant + a.deb_mon_rubro - a.cre_mon_rubro, 0)) = 0
       );

    -- 5.5 LIMPIEZA DE BANDAS DE PLAZO ANULADAS (SUMA NETO = 0)
    DELETE FROM sb_liq_diarios
     WHERE (fecha, cod_moneda, cod_cuenta, plazo) IN (
           SELECT fecha, cod_moneda, cod_cuenta, plazo
             FROM sb_liq_diarios
            WHERE fecha = v_fec_proceso
            GROUP BY fecha, cod_moneda, cod_cuenta, plazo
           HAVING SUM(importe) = 0
     );
 
    COMMIT;

EXCEPTION
    WHEN OTHERS THEN
       ROLLBACK;
       RAISE;
END PR_INS_LIQ_DIA_CON;

  --Procedimiento que genera el Archivo de Liquidez Diario----------
  PROCEDURE PR_GEN_LIQ_DIA_ASCII(p_fecha IN DATE DEFAULT NULL) IS
    v_ano_proceso VARCHAR2(4) DEFAULT '';
    v_mes_proceso VARCHAR2(2) DEFAULT '';
    v_dia_proceso VARCHAR2(2) DEFAULT '';
    v_nom_ascii   VARCHAR2(30) DEFAULT '';
    v_directorio  VARCHAR2(100) DEFAULT '';
    v_lin_datos   VARCHAR2(60) := NULL;
    v_can_tot_reg NUMBER(6) DEFAULT 0;
    v_can_reg     NUMBER(6) DEFAULT 0;
    v_archivo     utl_file.file_type;
    v_fec_proceso ge_calendarios.fec_actual%TYPE;
    v_cod_entidad ge_par_generales.cod_entidad%TYPE;
    v_fec_nombre  VARCHAR2(08) DEFAULT ''; --Se crea v_fec_nombre por AP 2796
    v_hini_ftp    ge_ra_log_ftp.hor_inicio%type;
    v_hfin_ftp    ge_ra_log_ftp.hor_fin%type;
    v_respuesta   VARCHAR2(4000);
    v_ip          VARCHAR2(100) := fug_obt_pardinamico('DIR_SVR_REP_ARCHIVOS');
    v_port        VARCHAR2(100) := fug_obt_pardinamico('PUERTO_FTP');
    v_user        VARCHAR2(100) := fug_obt_pardinamico('USU_FTP_REP_ARCHIVOS');
    v_pass        VARCHAR2(100) := fug_obt_pardinamico('PAS_FTP_REP_ARCHIVOS');
    v_carpeta     VARCHAR2(100) := fug_obt_pardinamico('DIR_SVR_REP_RIESGOS');
    --CURSOR PRINCIPAL DE LA TABLA EN DONDE SE INSERTAN LOS REGISTROS DIARIOS
    CURSOR c_archivo IS
      SELECT a.fecha,
             a.cod_moneda,
             a.cod_cuenta,
             (CASE 
                WHEN INSTR(','||REPLACE (fug_obt_pardinamico('REP_LIQUIDEZ_RUBRO_CERO'), ' ','')||',',
                       ','||TRIM(a.cod_cuenta)||','
                       ) > 0 THEN 0
                ELSE
                a.plazo
               END
              ) plazo,
             (CASE
               WHEN SUM(a.importe) < 0 THEN
                SUM(a.importe) * -1
               WHEN SUM(a.importe) >= 0 THEN
                SUM(a.importe)
             END) importe
        FROM sb_liq_diarios a
       WHERE a.fecha = v_fec_proceso
         AND INSTR(','||REPLACE (fug_obt_pardinamico('REP_LIQUIDEZ_EXCLUSION'), ' ','')||',',
               ','||TRIM(a.cod_cuenta)||',' ) = 0 
       GROUP BY a.fecha, a.cod_moneda, a.cod_cuenta, a.plazo
       ORDER BY a.fecha, a.cod_moneda, a.cod_cuenta, a.plazo;
  BEGIN
    --Genero el archivo ascii
    IF p_fecha IS NOT NULL THEN
      v_fec_proceso := p_fecha;
    ELSE
      v_fec_proceso := pag_cal.fu_obt_fec_actual(2);
    END IF;
    v_dia_proceso := to_char(v_fec_proceso, 'DD');
    v_mes_proceso := to_char(v_fec_proceso, 'MM');
    v_ano_proceso := to_char(v_fec_proceso, 'YYYY');
    v_fec_nombre  := to_char(v_fec_proceso, 'DDMMYYYY');
    v_directorio  := fug_obt_pardinamico('DIR_REP_FTP');
    --Verifico la existencia de registros
    BEGIN
      SELECT cod_entidad
        INTO v_cod_entidad
        FROM ge_par_generales
       WHERE rownum = 1;
    EXCEPTION
      WHEN OTHERS THEN
        raise_application_error(-20000,
                                'No existen parametros generales de la Entidad definidos');
    END;
    IF utl_file.is_open(v_archivo) THEN
      utl_file.fclose(v_archivo);
    END IF;
    ----------------------- PROCESAR ARCHIVO  ASCII ------------------------------
    --AP 2796. Se incluye la fecha (v_fec_nombre) en la generacion del nombre del archivo para que no se pisen los archivos en el directorio.
    v_nom_ascii := 'LI-' || v_cod_entidad || v_fec_nombre || '.DAT';
    v_archivo   := utl_file.fopen(v_directorio, v_nom_ascii, 'w');
    --ESCRIBIR EL ARCHIVO ASCII
    SELECT COUNT(COUNT(a.cod_cuenta))
      INTO v_can_tot_reg
      FROM sb_liq_diarios a
     WHERE a.fecha = v_fec_proceso
     GROUP BY a.fecha, a.cod_moneda, a.cod_cuenta, a.plazo
     ORDER BY a.fecha, a.cod_moneda, a.cod_cuenta, a.plazo;
    --Escribe la cabecera
    v_lin_datos := v_lin_datos || 'LIQUIDEZP ' || v_ano_proceso ||
                   v_mes_proceso || v_dia_proceso || v_cod_entidad || '0' ||
                   lpad(to_char(v_can_tot_reg), 6, '0');
    utl_file.put_line(v_archivo, v_lin_datos);
    --Escribe los detalles del archivo
    FOR arc IN c_archivo LOOP
      v_lin_datos := NULL;
      v_can_reg   := v_can_reg + 1;
      v_lin_datos := v_lin_datos || '15';
      v_lin_datos := v_lin_datos || lpad(TRIM(arc.cod_moneda), 4, '0');
      v_lin_datos := v_lin_datos || REGEXP_REPLACE(SUBSTR(RPAD(TO_CHAR(arc.cod_cuenta, 'TM9'), 10, '0'), 1, 10), '^(.{8})(.*)$', '\10\2');
      v_lin_datos := v_lin_datos || lpad(TRIM(arc.plazo), 2, '0');
      v_lin_datos := v_lin_datos || lpad(REPLACE(REPLACE(TRIM(to_char(arc.importe,
                                                                      '999,999,999,999,999.99')),
                                                         ',',
                                                         ''),
                                                 '.',
                                                 ''),
                                         17,
                                         '0');
      v_lin_datos := v_lin_datos || lpad(to_char(v_can_reg), 6, '0');
      utl_file.put_line(v_archivo, v_lin_datos);
    END LOOP;
    utl_file.fclose(v_archivo);
    /*Copiado a Ramail*/
    v_hini_ftp  := to_char(sysdate, 'hh24:mi:ss');
    v_respuesta := pa_file_ftp.fu_put_ascii(v_ip,
                                            v_port,
                                            v_user,
                                            v_pass,
                                            v_directorio,
                                            v_nom_ascii,
                                            v_carpeta || v_nom_ascii);

    v_hfin_ftp := to_char(sysdate, 'hh24:mi:ss');
    IF v_respuesta != 'OK' THEN
      -- ERROR AL ENVIAR ARCHIVO POR FTP
      -- Insertamos el error del envio al directorio compartido
      INSERT INTO ge_ra_log_ftp
        (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
      VALUES
        (SYSDATE, v_nom_ascii, v_respuesta, v_hini_ftp, v_hfin_ftp);
      COMMIT;
    END IF;

  EXCEPTION
    WHEN no_data_found THEN
      --- Fin del archivo
      utl_file.fclose(v_archivo);
    WHEN utl_file.invalid_path THEN
      utl_file.fclose(v_archivo);
      raise_application_error(-20000, 'Directorio invalido');
    WHEN utl_file.invalid_mode THEN
      utl_file.fclose(v_archivo);
      raise_application_error(-20000, 'Modo invalido');
    WHEN utl_file.invalid_filehandle THEN
      utl_file.fclose(v_archivo);
      raise_application_error(-20000, 'Invalida Filehandle');
    WHEN utl_file.invalid_operation THEN
      --- Fin del archivo
      utl_file.fclose(v_archivo);
    WHEN utl_file.read_error THEN
      utl_file.fclose(v_archivo);
      raise_application_error(-20000, 'Lectura errada');
    WHEN utl_file.write_error THEN
      utl_file.fclose(v_archivo);
      raise_application_error(-20000, 'Escritura errada');
    WHEN utl_file.internal_error THEN
      utl_file.fclose(v_archivo);
      raise_application_error(-20000, 'Error interno');
  END;

  /* Permite generar el informe de encaje legal mensual en base a la informacion contenida en el informe
  de encaje legal diario (ASCII) . */
  PROCEDURE PR_GEN_ENC_MENSUAL(P_FECHA IN SB_ENCAJES_ML.FECHA%TYPE DEFAULT NULL) IS

    v_fec_actual   sb_encajes_ml.fecha%type;
    v_fec_proxima  sb_encajes_ml.fecha%type;
    v_fec_registro sb_encajes_ml.fecha%type;
    v_fec_contable sb_encajes_ml.fecha%type;

    /* Calcula el encaje legal para moneda local */
    PROCEDURE LP_CAL_ENC_MON_LOCAL(P_FEC_ACTUAL   IN DATE,
                                   P_FEC_REGISTRO IN DATE);
    /* Calcular encaje legal moneda extranjera */
    PROCEDURE LP_CAL_ENC_MON_EXTR(P_FEC_ACTUAL   IN DATE,
                                  P_FEC_REGISTRO IN DATE);
    /* Calcular el encaje especial */
    PROCEDURE LP_CAL_ENC_ESPECIAL(P_FEC_ACTUAL IN DATE);
    nv_cantidad number(03);

    /* Calcula el encaje legal para moneda local */
    PROCEDURE LP_CAL_ENC_MON_LOCAL(P_FEC_ACTUAL   IN DATE,
                                   P_FEC_REGISTRO IN DATE) IS

      --Variables.
      v_sal_actual         sb_encajes_ml.sal_actual%type;
      v_sujeto_d           sb_encajes_ml.sujeto_d%type;
      v_sujeto_e           sb_encajes_ml.sujeto_e%type;
      v_mto_remunerar      sb_encajes_ml.mto_remunerar%type;
      v_tot_exigido        sb_encajes_ml.tot_exigido%type;
      v_sujeto_f           sb_encajes_ml.sujeto_f%type;
      v_sujeto_g           sb_encajes_ml.sujeto_g%type;
      v_encaje_h           sb_encajes_ml.encaje_h%type;
      v_encaje_i           sb_encajes_ml.encaje_i%type;
      v_encaje_j           sb_encajes_ml.encaje_j%type;
      v_sal_actual1a       sb_encajes_ml.sal_actual%type;
      v_sujeto_e1          sb_encajes_ml.sujeto_e%type;
      v_sujeto_g1          sb_encajes_ml.sujeto_e%type;
      v_cod_rub_dep_encaje ge_par_dinamicos.val_parametro%type := null;
      v_bcp_depositado     number(18, 2) := 0;
      v_mto_encaje         number(18, 2) := 0;

    BEGIN

      -- Vista.
      begin
        select nvl(sum(a.importe), 0)
          into v_sal_actual1a
          from sb_enc_circular254 a
         where a.fecha = p_fec_actual
           and a.plazo = '10'
           and a.cod_moneda = '6900';
      exception
        when others then
          raise_application_error(-20001,
                                  'Error en la sumatoria v_sal_actual1a ' ||
                                  sqlerrm);
      end;
      v_sal_actual := nvl(v_sal_actual1a, 0);
      v_sujeto_d   := v_sal_actual;

      --PLAZO
      --Sujeto al 18%
      --De 1 a 180
      begin
        select nvl(sum(a.importe), 0)
          into v_sujeto_e1
          from sb_enc_circular254 a
         where a.fecha = p_fec_actual
           and a.plazo in ('20', '30', '40', '50', '60')
           and a.cod_moneda = '6900';
      exception
        when others then
          raise_application_error(-20001,
                                  'Error en la sumatoria v_sujeto_e1 ' ||
                                  sqlerrm);
      end;
      v_sujeto_e := nvl(v_sujeto_e1, 0);
      v_sujeto_f := 0; --no se utiliza

      --Sujeto al 0%
      --De 361 a más de 1080
      begin
        select nvl(sum(a.importe), 0)
          into v_sujeto_g1
          from sb_enc_circular254 a
         where a.fecha = p_fec_actual
           and a.plazo in ('71', '73', '80')
           and a.cod_moneda = '6900'
           and a.cod_cuenta != 266;
      exception
        when others then
          raise_application_error(-20001,
                                  'Error en la sumatoria v_sujeto_g1 ' ||
                                  sqlerrm);
      end;
      v_sujeto_g := nvl(v_sujeto_g1, 0);

      v_encaje_h      := 0;
      v_encaje_i      := round((v_sujeto_d + v_sujeto_e) * 0.18, 0); -- Cambió el 10/03/2011
      v_encaje_j      := 0;
      v_tot_exigido   := round(v_encaje_i, 0);
      v_mto_remunerar := round((v_sujeto_d + v_sujeto_e) * 0.11, 0); -- Res. 8 del 10/03/2011 (18% - 7%)

      --Modificado para traer monto de deposito en BCP--
      v_cod_rub_dep_encaje := fug_obt_pardinamico('COD_RUB_DEP_ENC_LEGAL',
                                                  null,
                                                  null,
                                                  pag_gen.FU_OBT_MON_LOCAL);
      begin
        select sum(round((nvl(a.sal_mon_loc_ant, 0) +
                         nvl(a.deb_mon_local, 0) - nvl(a.cre_mon_local, 0)),
                         0))
          into v_bcp_depositado
          from cb_sal_consolidados_dia a
         where a.fecha =
               (select max(b.fecha)
                  from cb_sal_consolidados_dia b
                 where b.fecha <= p_fec_actual
                   and b.cod_rubro = v_cod_rub_dep_encaje)
           and a.cod_rubro = v_cod_rub_dep_encaje;
      exception
        when others then
          raise_application_error(-20001,
                                  'Error en la sumatoria del monto bcp depositado ' ||
                                  sqlerrm);
      end;

      begin
        insert into sb_encajes_ml
          (fecha,
           sal_julio,
           sal_actual,
           sujeto_d,
           sujeto_e,
           sujeto_f,
           sujeto_g,
           encaje_h,
           encaje_i,
           encaje_j,
           tot_exigido,
           mto_remunerar,
           bcp_depositado)
        values
          (p_fec_registro,
           0,
           v_sujeto_d,
           v_sujeto_d,
           v_sujeto_e,
           v_sujeto_f,
           v_sujeto_g,
           v_encaje_h,
           v_encaje_i,
           v_encaje_j,
           v_tot_exigido,
           v_mto_remunerar,
           v_bcp_depositado);
      exception
        when others then
          raise_application_error(-20001,
                                  'Error al insertar en sb_encajes_ml ' ||
                                  sqlerrm);
      end;
    EXCEPTION
      when others then
        if sqlcode <= -20000 then
          raise;
        else
          raise_application_error(-20000,
                                  'LP_CAL_ENC_MON_LOCAL ' || sqlerrm);
        end if;
    END;

    /* Calcular encaje legal moneda extranjera */
    PROCEDURE LP_CAL_ENC_MON_EXTR(P_FEC_ACTUAL   IN DATE,
                                  P_FEC_REGISTRO IN DATE) IS

      v_sujeto_a1          sb_encajes_me.sujeto_a%type;
      v_sujeto_a2          sb_encajes_me.sujeto_a%type;
      v_sujeto_a           sb_encajes_me.sujeto_a%type;
      v_sujeto_c           sb_encajes_me.sujeto_c%type;
      v_mto_remunerar      sb_encajes_me.mto_remunerar%type;
      v_tot_exigido        sb_encajes_me.tot_exigido%type;
      v_cotizacion         ge_cotizaciones.val_conversion%type;
      v_encaje_a           sb_encajes_me.encaje_a%type;
      v_encaje_b           sb_encajes_me.encaje_b%type;
      v_encaje_c           sb_encajes_me.encaje_c%type;
      v_encaje_d           sb_encajes_me.encaje_d%type;
      v_sujeto_d           sb_encajes_me.sujeto_d%type;
      v_sujeto_b           sb_encajes_me.sujeto_b%type;
      v_cod_moneda         ba_monedas.cod_moneda%type;
      v_cod_rub_dep_encaje ge_par_dinamicos.val_parametro%type := null;
      v_bcp_depositado     number(18, 2) := 0;
      v_mto_encaje         number(18, 2) := 0;

      Cursor c_monedas is
        SELECT DISTINCT (sb.cod_moneda) cod_moneda
              FROM sb_enc_circular254 sb
             WHERE sb.cod_moneda != '6900'
               AND sb.fecha = p_fec_actual;
    BEGIN

      For reg in c_monedas loop

        --Obtengo la sigla de la moneda.
        begin
          select ba.cod_moneda
            into v_cod_moneda
            from ba_monedas ba
           where ba.cod_mon_bco_central = reg.cod_moneda;
        exception
          when no_data_found then
            raise_application_error(-20001,
                                    'Moneda ' || reg.cod_moneda ||
                                    ' no definida');
          when others then
            raise_application_error(-20001,
                                    'Error en la búsqueda de sigla de la moneda ' ||
                                    sqlerrm);
        end;
        --Vista.
        --Sujeto al 25%
        begin
          select nvl(sum(a.importe), 0)
            into v_sujeto_a1
            from sb_enc_circular254 a
           where a.fecha = p_fec_actual
             and a.plazo = '10'
             and a.cod_moneda = reg.cod_moneda;
        exception
          when others then
            raise_application_error(-20001,
                                    'Error en la sumatoria v_sujeto_a1 ' ||
                                    sqlerrm);
        end;
        --De 1 y 360 días
        --Sujeto al 25%
        begin
          select nvl(sum(a.importe), 0)
            into v_sujeto_a2
            from sb_enc_circular254 a
           where a.fecha = p_fec_actual
             and a.plazo in ('20', '30', '40', '50', '60')
             and a.cod_moneda = reg.cod_moneda;
        exception
          when others then
            raise_application_error(-20001,
                                    'Error en la sumatoria v_sujeto_a2 ' ||
                                    sqlerrm);
        end;
        V_SUJETO_A := round(nvl(V_SUJETO_A1, 0) + nvl(V_SUJETO_A2, 0), 2); --CNFDELEG-1 / RABP-CNF / 06-2016

        --De 361 a 540 días
        --Sujeto al 16,5%
        begin
          select nvl(sum(a.importe), 0)
            into v_sujeto_b
            from sb_enc_circular254 a
           where a.fecha = p_fec_actual
             and a.plazo = '71'
             and a.cod_moneda = reg.cod_moneda;
        exception
          when others then
            raise_application_error(-20001,
                                    'Error en la sumatoria v_sujeto_b ' ||
                                    sqlerrm);
        end;
        --De 541 0 1080 días
        --Sujeto al 0%
        begin
          select nvl(sum(a.importe), 0)
            into v_sujeto_c
            from sb_enc_circular254 a
           where a.fecha = p_fec_actual
             and a.plazo = '73'
             and a.cod_moneda = reg.cod_moneda;
        exception
          when others then
            raise_application_error(-20001,
                                    'Error en la sumatoria v_sujeto_c ' ||
                                    sqlerrm);
        end;
        --De 1081 a más días
        --Sujeto al 0%
        begin
          select nvl(sum(a.importe), 0)
            into v_sujeto_d
            from sb_enc_circular254 a
           where a.fecha = p_fec_actual
             and a.plazo = '80'
             and a.cod_moneda = reg.cod_moneda;
        exception
          when others then
            raise_application_error(-20001,
                                    'Error en la sumatoria v_sujeto_d ' ||
                                    sqlerrm);
        end;
        v_cotizacion    := pag_gen.fu_obt_cotizacion(v_cod_moneda,
                                                     p_fec_actual);
        v_encaje_a      := round(v_sujeto_a * 0.24, 2);
        v_encaje_b      := round(v_sujeto_b * 0.165, 2);
        v_encaje_c      := round(v_sujeto_c * 0.0, 0);
        v_encaje_d      := round(v_sujeto_d * 0.0, 0);
        v_mto_remunerar := round((v_sujeto_a * 0.14) + (v_sujeto_b * 0.065),
                                 2);
        v_tot_exigido   := round(v_encaje_a + v_encaje_b, 2);

        --Modificado para traer monto de deposito en BCP--
        v_cod_rub_dep_encaje := fug_obt_pardinamico('COD_RUB_DEP_ENC_LEGAL',
                                                    null,
                                                    null,
                                                    v_cod_moneda);
        begin
          select sum(round(nvl(a.sal_mon_rub_ant, 0) +
                           nvl(a.deb_mon_rubro, 0) -
                           nvl(a.cre_mon_rubro, 0),
                           2))
            into v_bcp_depositado
            from cb_sal_consolidados_dia a
           where a.fecha =
                 (select max(b.fecha)
                    from cb_sal_consolidados_dia b
                   where b.fecha <= p_fec_actual
                     and b.cod_rubro = v_cod_rub_dep_encaje)
             and a.cod_rubro = v_cod_rub_dep_encaje;
        exception
          when others then
            raise_application_error(-20001,
                                    'Error en la sumatoria del monto bcp depositado ' ||
                                    sqlerrm);
        end;

        ---------------------------------------------------
        begin
          insert into sb_encajes_me
            (fecha,
             cod_moneda,
             val_cotizacion,
             sujeto_a,
             sujeto_b,
             sujeto_c,
             sujeto_d,
             encaje_a,
             encaje_b,
             encaje_c,
             encaje_d,
             tot_exigido,
             mto_remunerar,
             bcp_depositado,
             pos_observada)
          values
            (p_fec_registro,
             v_cod_moneda,
             v_cotizacion,
             v_sujeto_a,
             v_sujeto_b,
             v_sujeto_c,
             v_sujeto_d,
             v_encaje_a,
             v_encaje_b,
             v_encaje_c,
             v_encaje_d,
             v_tot_exigido,
             v_mto_remunerar,
             v_bcp_depositado,
             0);

        exception
          when others then
            raise_application_error(-20001,
                                    'Error al insertar en sb_encajes_me ' ||
                                    sqlerrm);
        end;
      end loop;

    EXCEPTION
      when others then
        if sqlcode <= -20000 then
          raise;
        else
          raise_application_error(-20000,
                                  'LP_CAL_ENC_MON_EXTR ' || sqlerrm);
        end if;
    END;

    /* Calcular el encaje especial */
    PROCEDURE LP_CAL_ENC_ESPECIAL(P_FEC_ACTUAL IN DATE) IS

      v_mto_encaje sb_encajes_esp.bcp_depositado%type;
      v_redondeo   number(2);

      Cursor cta_cancelada is
        Select b.tip_valor,
               c.val_tasa,
               a.capital,
               a.cod_modulo,
               a.cod_modalidad,
               a.cod_moneda,
               a.nro_cuenta,
               a.beneficiario,
               a.fec_apertura,
               nvl(a.fec_pago, P_FEC_ACTUAL) fec_pago,
               nvl(a.fec_pago, P_FEC_ACTUAL) - a.fec_apertura dia_transcurridos,
               a.fec_vencimiento
          from ah_cta_certificados a, ge_tasas b, ge_tas_fechas c
         where a.fec_pago < a.fec_vencimiento
           and a.fec_pago > a.fec_apertura --Mismo día no cancela
           and a.fec_cam_estado = p_fec_actual
           and a.estado in ('P', 'C')
           and b.cod_tasa = c.cod_tasa
           and c.cod_tasa = fug_obt_pardinamico('SNP_TAS_ENC_LEG_ESPECIAL', a.cod_modulo)
           and a.cod_moneda = c.cod_moneda
           and c.cod_modulo = a.cod_modulo
           and c.fec_vigencia <= pag_cal.fu_obt_fec_actual(a.cod_modulo)
           and a.fec_vencimiento - a.fec_apertura between c.val_minimo and
               c.val_maximo --plazo
           and not exists (select 1
                  from sb_encajes_esp d
                 where d.nro_cuenta = a.nro_cuenta)
        UNION ALL
        -- Cta. Plazo
        Select b.tip_valor,
               c.val_tasa,
               a.capital,
               a.cod_modulo,
               a.cod_modalidad,
               a.cod_moneda,
               a.nro_cuenta,
               a.denominacion,
               a.fec_apertura,
               nvl(a.fec_pago, P_FEC_ACTUAL) fec_pago,
               nvl(a.fec_pago, P_FEC_ACTUAL) - a.fec_apertura dia_transcurridos,
               a.fec_vencimiento
          from ah_cta_plazos a, ge_tasas b, ge_tas_fechas c
         where a.fec_pago < a.fec_vencimiento
           and a.fec_pago > a.fec_apertura --Mismo día no cancela
           and a.fec_cam_estado = p_fec_actual
           and a.estado in ('P', 'C')
           and b.cod_tasa = c.cod_tasa
           and c.cod_tasa =
               fug_obt_pardinamico('COD_TAS_ENC_LEG_ESPECIAL', a.cod_modulo)
           and a.cod_moneda = c.cod_moneda
           and c.cod_modulo = a.cod_modulo
           and c.fec_vigencia <= pag_cal.fu_obt_fec_actual(a.cod_modulo)
           and a.fec_vencimiento - a.fec_apertura between c.val_minimo and
               c.val_maximo --plazo
           and not exists (select 1
                  from sb_encajes_esp d
                 where d.nro_cuenta = a.nro_cuenta);

    BEGIN
      For reg in cta_cancelada loop
        v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                                          reg.cod_modulo,
                                          reg.cod_modalidad,
                                          reg.cod_moneda);

        if reg.tip_valor = 'P' --Porcentaje
           and nvl(reg.val_tasa, 0) != 0 then
          v_mto_encaje := round((nvl(reg.capital, 0) * reg.val_tasa) / 100,
                                v_redondeo);
        elsif reg.tip_valor = 'V' then
          --Valor
          v_mto_encaje := reg.val_tasa;
        end if;

        insert into sb_encajes_esp
          (nro_cuenta,
           cod_modulo,
           cod_modalidad,
           cod_moneda,
           beneficiario,
           importe,
           fec_emision,
           fec_rescate,
           dia_transcurrido,
           por_encaje,
           bcp_depositado,
           fec_vencimiento)
        values
          (reg.nro_cuenta,
           reg.cod_modulo,
           reg.cod_modalidad,
           reg.cod_moneda,
           reg.beneficiario,
           reg.capital,
           reg.fec_apertura,
           reg.fec_pago,
           reg.dia_transcurridos,
           reg.val_tasa,
           v_mto_encaje,
           reg.fec_vencimiento);

      end loop;

    END;

    --Proceso Principal.
  BEGIN
    if p_fecha is not null then
      v_fec_actual := p_fecha;
    else
      --v_fec_actual := pag_cal.fu_obt_fec_actual(1);
      --Obtengo la fecha de generacion
      v_fec_contable := nvl(pag_cal.fu_obt_fec_actual(2),
                            pag_cal.fu_obt_fec_actual(1));

      select nvl(max(a.fecha), pag_cal.fu_obt_fec_actual(1))
        into v_fec_actual
        from sb_enc_circular254 a;

      if v_fec_actual < v_fec_contable then
        v_fec_actual := v_fec_contable;
      end if;
    end if;
    v_fec_proxima  := pag_cal.FU_OBT_FEC_SIG_HAB(v_fec_actual, null);
    nv_cantidad    := v_fec_proxima - v_fec_actual;
    v_fec_registro := v_fec_actual;
    --
    for i in 1 .. nv_cantidad loop
      --
      delete sb_encajes_ml sb where sb.fecha = v_fec_registro;
      delete sb_encajes_me sb where sb.fecha = v_fec_registro;
      --
      lp_cal_enc_mon_local(v_fec_actual, v_fec_registro);
      lp_cal_enc_mon_extr(v_fec_actual, v_fec_registro);
      lp_cal_enc_especial(v_fec_actual);
      --Para insertar los registros por Fin de Semana y Feriados.
      v_fec_registro := v_fec_registro + 1;
    end loop;
  END;

  /* Permite generar REPROCESO del informe de encaje legal mensual en base a la informacion contenida en el informe
  de encaje legal diario (ASCII) . */
  PROCEDURE PR_GEN_REP_ENC_MENSUAL IS

    v_fec_actual   sb_encajes_ml.fecha%type;
    v_fec_proxima  sb_encajes_ml.fecha%type;
    v_fec_registro sb_encajes_ml.fecha%type;
    v_fec_contable sb_encajes_ml.fecha%type;

    /* Calcula el encaje legal para moneda local */
    PROCEDURE LP_CAL_ENC_MON_LOCAL(P_FEC_ACTUAL   IN DATE,
                                   P_FEC_REGISTRO IN DATE);
    /* Calcular encaje legal moneda extranjera */
    PROCEDURE LP_CAL_ENC_MON_EXTR(P_FEC_ACTUAL   IN DATE,
                                  P_FEC_REGISTRO IN DATE);
    /* Calcular el encaje especial */
    PROCEDURE LP_CAL_ENC_ESPECIAL(P_FEC_ACTUAL IN DATE);
    nv_cantidad number(03);

    /* Calcula el encaje legal para moneda local */
    PROCEDURE LP_CAL_ENC_MON_LOCAL(P_FEC_ACTUAL   IN DATE,
                                   P_FEC_REGISTRO IN DATE) IS

      --Variables.
      v_sal_actual         sb_encajes_ml.sal_actual%type;
      v_sujeto_d           sb_encajes_ml.sujeto_d%type;
      v_sujeto_e           sb_encajes_ml.sujeto_e%type;
      v_mto_remunerar      sb_encajes_ml.mto_remunerar%type;
      v_tot_exigido        sb_encajes_ml.tot_exigido%type;
      v_sujeto_f           sb_encajes_ml.sujeto_f%type;
      v_sujeto_g           sb_encajes_ml.sujeto_g%type;
      v_encaje_h           sb_encajes_ml.encaje_h%type;
      v_encaje_i           sb_encajes_ml.encaje_i%type;
      v_encaje_j           sb_encajes_ml.encaje_j%type;
      v_sal_actual1a       sb_encajes_ml.sal_actual%type;
      v_sujeto_e1          sb_encajes_ml.sujeto_e%type;
      v_sujeto_g1          sb_encajes_ml.sujeto_e%type;
      v_cod_rub_dep_encaje varchar2(15) := null;
      v_bcp_depositado     number(18, 2) := 0;
      v_mto_encaje         number(18, 2) := 0;

    BEGIN

      -- Vista.
      select nvl(sum(a.importe), 0)
        into v_sal_actual1a
        from sb_enc_circular254 a
       where a.fecha = p_fec_actual
         and a.plazo = '10'
         and a.cod_moneda = '6900';

      v_sal_actual := nvl(v_sal_actual1a, 0);
      v_sujeto_d   := v_sal_actual;

      --PLAZO
      --Sujeto al 18%
      --De 1 a 180
      select nvl(sum(a.importe), 0)
        into v_sujeto_e1
        from sb_enc_circular254 a
       where a.fecha = p_fec_actual
         and a.plazo in ('20', '30', '40', '50', '60')
         and a.cod_moneda = '6900';

      v_sujeto_e := nvl(v_sujeto_e1, 0);
      v_sujeto_f := 0; --no se utiliza

      --Sujeto al 0%
      --De 361 a más de 1080
      select nvl(sum(a.importe), 0)
        into v_sujeto_g1
        from sb_enc_circular254 a
       where a.fecha = p_fec_actual
         and a.plazo in ('71', '73', '80')
         and a.cod_moneda = '6900';

      v_sujeto_g := nvl(v_sujeto_g1, 0);

      v_encaje_h      := 0;
      v_encaje_i      := round((v_sujeto_d + v_sujeto_e) * 0.18, 0); -- Cambió el 10/03/2011
      v_encaje_j      := 0;
      v_tot_exigido   := round(v_encaje_i, 0);
      v_mto_remunerar := round((v_sujeto_d + v_sujeto_e) * 0.11, 0); -- Res. 8 del 10/03/2011 (18% - 7%)

      --Modificado para traer monto de deposito en BCP--
      v_cod_rub_dep_encaje := fug_obt_pardinamico('COD_RUB_DEP_ENC_LEGAL',
                                                  null,
                                                  null,
                                                  pag_gen.FU_OBT_MON_LOCAL);

      select sum(round((nvl(a.sal_mon_loc_ant, 0) + nvl(a.deb_mon_local, 0) -
                       nvl(a.cre_mon_local, 0)),
                       0))
        into v_bcp_depositado
        from cb_sal_consolidados_dia a
       where a.fecha =
             (select max(b.fecha)
                from cb_sal_consolidados_dia b
               where b.fecha <= p_fec_actual
                 and b.cod_rubro = v_cod_rub_dep_encaje)
         and a.cod_rubro = v_cod_rub_dep_encaje;

      --Obtengo el parametrizado del deposito del encaje en BCP.
      v_mto_encaje := fug_obt_pardinamico('MTO_DEP_ENC_BCP',
                                          null,
                                          null,
                                          pag_gen.FU_OBT_MON_LOCAL);

      if v_mto_encaje != v_bcp_depositado then
        v_bcp_depositado := v_mto_encaje;
      end if;
      ---------------------------------------------------
      insert into sb_encajes_ml
        (fecha,
         sal_julio,
         sal_actual,
         sujeto_d,
         sujeto_e,
         sujeto_f,
         sujeto_g,
         encaje_h,
         encaje_i,
         encaje_j,
         tot_exigido,
         mto_remunerar,
         bcp_depositado)
      values
        (p_fec_registro,
         0,
         v_sujeto_d,
         v_sujeto_d,
         v_sujeto_e,
         v_sujeto_f,
         v_sujeto_g,
         v_encaje_h,
         v_encaje_i,
         v_encaje_j,
         v_tot_exigido,
         v_mto_remunerar,
         v_bcp_depositado);

    EXCEPTION
      WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20000, SQLERRM || ' SB_ENCAJES_ML');
    END;

    /* Calcular encaje legal moneda extranjera */
    PROCEDURE LP_CAL_ENC_MON_EXTR(P_FEC_ACTUAL   IN DATE,
                                  P_FEC_REGISTRO IN DATE) IS

      v_sujeto_a1          sb_encajes_me.sujeto_a%type;
      v_sujeto_a2          sb_encajes_me.sujeto_a%type;
      v_sujeto_a           sb_encajes_me.sujeto_a%type;
      v_sujeto_c           sb_encajes_me.sujeto_c%type;
      v_mto_remunerar      sb_encajes_me.mto_remunerar%type;
      v_tot_exigido        sb_encajes_me.tot_exigido%type;
      v_cotizacion         ge_cotizaciones.val_conversion%type;
      v_encaje_a           sb_encajes_me.encaje_a%type;
      v_encaje_b           sb_encajes_me.encaje_b%type;
      v_encaje_c           sb_encajes_me.encaje_c%type;
      v_encaje_d           sb_encajes_me.encaje_d%type;
      v_sujeto_d           sb_encajes_me.sujeto_d%type;
      v_sujeto_b           sb_encajes_me.sujeto_b%type;
      v_cod_moneda         ba_monedas.cod_moneda%type;
      v_cod_rub_dep_encaje varchar2(15) := null;
      v_bcp_depositado     number(18, 2) := 0;
      v_mto_encaje         number(18, 2) := 0;

      Cursor c_monedas is
        select distinct (sb.cod_moneda) cod_moneda
          from sb_enc_circular254 sb
         where sb.cod_moneda != '6900'
           and sb.fecha = P_FEC_ACTUAL
           and sb.plazo <> '99';
    BEGIN

      For reg in c_monedas loop

        --Obtengo la sigla de la moneda.
        select ba.cod_moneda
          into v_cod_moneda
          from ba_monedas ba
         where ba.cod_mon_bco_central = reg.cod_moneda;

        --Vista.
        --Sujeto al 25%
        select nvl(sum(a.importe), 0)
          into v_sujeto_a1
          from sb_enc_circular254 a
         where a.fecha = p_fec_actual
           and a.plazo = '10'
           and a.cod_moneda = reg.cod_moneda;

        --De 1 y 360 días
        --Sujeto al 25%
        select nvl(sum(a.importe), 0)
          into v_sujeto_a2
          from sb_enc_circular254 a
         where a.fecha = p_fec_actual
           and a.plazo in ('20', '30', '40', '50', '60')
           and a.cod_moneda = reg.cod_moneda;

        V_SUJETO_A := round(nvl(V_SUJETO_A1, 0) + nvl(V_SUJETO_A2, 0), 2); --CNFDELEG-1 / RABP-CNF / 06-2016

        --De 361 a 540 días
        --Sujeto al 16,5%
        select nvl(sum(a.importe), 0)
          into v_sujeto_b
          from sb_enc_circular254 a
         where a.fecha = p_fec_actual
           and a.plazo = '71'
           and a.cod_moneda = reg.cod_moneda;

        --De 541 0 1080 días
        --Sujeto al 0%
        select nvl(sum(a.importe), 0)
          into v_sujeto_c
          from sb_enc_circular254 a
         where a.fecha = p_fec_actual
           and a.plazo = '73'
           and a.cod_moneda = reg.cod_moneda;

        --De 1081 a más días
        --Sujeto al 0%
        select nvl(sum(a.importe), 0)
          into v_sujeto_d
          from sb_enc_circular254 a
         where a.fecha = p_fec_actual
           and a.plazo = '80'
           and a.cod_moneda = reg.cod_moneda;

        v_cotizacion    := pag_gen.fu_obt_cotizacion(v_cod_moneda,
                                                     p_fec_actual);
        v_encaje_a      := round(v_sujeto_a * 0.24, 2);
        v_encaje_b      := round(v_sujeto_b * 0.165, 2);
        v_encaje_c      := round(v_sujeto_c * 0.0, 0);
        v_encaje_d      := round(v_sujeto_d * 0.0, 0);
        v_mto_remunerar := round((v_sujeto_a * 0.14) + (v_sujeto_b * 0.065),
                                 2);
        v_tot_exigido   := round(v_encaje_a + v_encaje_b, 2);

        --Modificado para traer monto de deposito en BCP--
        v_cod_rub_dep_encaje := fug_obt_pardinamico('COD_RUB_DEP_ENC_LEGAL',
                                                    null,
                                                    null,
                                                    v_cod_moneda);
        select sum(round(nvl(a.sal_mon_rub_ant, 0) +
                         nvl(a.deb_mon_rubro, 0) - nvl(a.cre_mon_rubro, 0),
                         2))
          into v_bcp_depositado
          from cb_sal_consolidados_dia a
         where a.fecha =
               (select max(b.fecha)
                  from cb_sal_consolidados_dia b
                 where b.fecha <= p_fec_actual
                   and b.cod_rubro = v_cod_rub_dep_encaje)
           and a.cod_rubro = v_cod_rub_dep_encaje;

        --Obtengo el parametrizado del deposito del encaje en BCP.
        v_mto_encaje := nvl(fug_obt_pardinamico('MTO_DEP_ENC_BCP',
                                                null,
                                                null,
                                                v_cod_moneda),
                            0);

        if v_mto_encaje != v_bcp_depositado then
          v_bcp_depositado := v_mto_encaje;
        end if;
        ---------------------------------------------------

        insert into sb_encajes_me
          (fecha,
           cod_moneda,
           val_cotizacion,
           sujeto_a,
           sujeto_b,
           sujeto_c,
           sujeto_d,
           encaje_a,
           encaje_b,
           encaje_c,
           encaje_d,
           tot_exigido,
           mto_remunerar,
           bcp_depositado,
           pos_observada)
        values
          (p_fec_registro,
           v_cod_moneda,
           v_cotizacion,
           v_sujeto_a,
           v_sujeto_b,
           v_sujeto_c,
           v_sujeto_d,
           v_encaje_a,
           v_encaje_b,
           v_encaje_c,
           v_encaje_d,
           v_tot_exigido,
           v_mto_remunerar,
           v_bcp_depositado,
           0);

      end loop;

    EXCEPTION
      WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20000, SQLERRM || ' SB_ENCAJES_ME');
    END;

    /* Calcular el encaje especial */
    PROCEDURE LP_CAL_ENC_ESPECIAL(P_FEC_ACTUAL IN DATE) IS
      v_mto_encaje sb_encajes_esp.bcp_depositado%type;
      v_redondeo   number(2);

      Cursor cta_cancelada is
        Select b.tip_valor,
               c.val_tasa,
               a.capital,
               a.cod_modulo,
               a.cod_modalidad,
               a.cod_moneda,
               a.nro_cuenta,
               a.beneficiario,
               a.fec_apertura,
               nvl(a.fec_pago, P_FEC_ACTUAL) fec_pago,
               nvl(a.fec_pago, P_FEC_ACTUAL) - a.fec_apertura dia_transcurridos,
               a.fec_vencimiento
          from ah_cta_certificados a, ge_tasas b, ge_tas_fechas c
         where a.fec_pago < a.fec_vencimiento
           and a.fec_pago > a.fec_apertura --Mismo día no cancela
           and a.fec_cam_estado = p_fec_actual
           and a.estado in ('P', 'C')
           and b.cod_tasa = c.cod_tasa
           and c.cod_tasa =
               fug_obt_pardinamico('COD_TAS_ENC_LEG_ESPECIAL', a.cod_modulo)
           and a.cod_moneda = c.cod_moneda
           and c.cod_modulo = a.cod_modulo
           and c.fec_vigencia <= pag_cal.fu_obt_fec_actual(a.cod_modulo)
           and a.fec_vencimiento - a.fec_apertura between c.val_minimo and
               c.val_maximo --plazo
           and not exists (select 1
                  from sb_encajes_esp d
                 where d.nro_cuenta = a.nro_cuenta);

    BEGIN
      For reg in cta_cancelada loop
        v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                                          reg.cod_modulo,
                                          reg.cod_modalidad,
                                          reg.cod_moneda);

        if reg.tip_valor = 'P' --Porcentaje
           and nvl(reg.val_tasa, 0) != 0 then
          v_mto_encaje := round((nvl(reg.capital, 0) * reg.val_tasa) / 100,
                                v_redondeo);
        elsif reg.tip_valor = 'V' then
          --Valor
          v_mto_encaje := reg.val_tasa;
        end if;

        insert into sb_encajes_esp
          (nro_cuenta,
           cod_modulo,
           cod_modalidad,
           cod_moneda,
           beneficiario,
           importe,
           fec_emision,
           fec_rescate,
           dia_transcurrido,
           por_encaje,
           bcp_depositado,
           fec_vencimiento)
        values
          (reg.nro_cuenta,
           reg.cod_modulo,
           reg.cod_modalidad,
           reg.cod_moneda,
           reg.beneficiario,
           reg.capital,
           reg.fec_apertura,
           reg.fec_pago,
           reg.dia_transcurridos,
           reg.val_tasa,
           v_mto_encaje,
           reg.fec_vencimiento);

      end loop;

    END;

    --Proceso Principal.
  BEGIN
    --Obtengo la fecha de generacion
    v_fec_actual   := fug_obt_pardinamico('FEC_REP_ENC_MENSUAL');
    v_fec_proxima  := pag_cal.FU_OBT_FEC_SIG_HAB(v_fec_actual, null);
    nv_cantidad    := v_fec_proxima - v_fec_actual;
    v_fec_registro := v_fec_actual;
    --
    for i in 1 .. nv_cantidad loop
      --
      delete sb_encajes_ml sb where sb.fecha = v_fec_registro;
      delete sb_encajes_me sb where sb.fecha = v_fec_registro;
      --
      lp_cal_enc_mon_local(v_fec_actual, v_fec_registro);
      lp_cal_enc_mon_extr(v_fec_actual, v_fec_registro);
      --Para insertar los registros por Fin de Semana y Feriados.
      v_fec_registro := v_fec_registro + 1;
    end loop;
  END;

  -- OMM 07/12/2011 Proceso que Genera archivo de Personas Inhibidas para envio a BCP
  PROCEDURE PR_GEN_INHIBIDAS(p_fecha IN DATE DEFAULT NULL) IS
    v_nom_ascii   VARCHAR2(30) DEFAULT '';
    v_directorio  VARCHAR2(100) DEFAULT '';
    v_lin_datos   VARCHAR2(500) := NULL;
    v_can_tot_reg NUMBER(6) DEFAULT 0;
    v_can_reg     NUMBER(6) DEFAULT 0;
    v_cod_causal  NUMBER(2); -- Codigo de Causal segun la fecha de vencimiento
    v_plazo       number(2); -- Plazo segun calculo de fecha de vencimiento
    v_archivo     utl_file.file_type;
    v_fec_proceso ge_calendarios.fec_actual%TYPE;
    v_cod_entidad ge_par_generales.cod_entidad%TYPE;
    -- Variables para FTP
    v_ip          VARCHAR2(100) := fug_obt_pardinamico('DIR_SVR_REP_ARCHIVOS');
    v_port        VARCHAR2(100) := '121';
    v_user        VARCHAR2(100) := fug_obt_pardinamico('USU_FTP_REP_ARCHIVOS');
    v_pass        VARCHAR2(100) := fug_obt_pardinamico('PAS_FTP_REP_ARCHIVOS');
    v_respuesta   VARCHAR2(4000);
    v_hini_ftp    ge_ra_log_ftp.hor_inicio%type;
    v_hfin_ftp    ge_ra_log_ftp.hor_fin%type;
    
    v_causa       VARCHAR2(100) := fug_obt_pardinamico('COD_CAU_INH_BLO_CTA');
    
    --CURSOR PRINCIPAL DE LA TABLA EN DONDE SE INSERTAN LOS REGISTROS DIARIOS
    CURSOR c_archivo IS
      Select distinct '006' Tipo_formulario,
                      '0000' Sucursal,
                      to_char(a.fec_inicio, 'YYYYMMDD') Fecha_Emision,
                      c.pri_apellido || ' ' || c.seg_apellido Apellido,
                      c.pri_nombre || ' ' || c.seg_nombre Nombre,
                      decode(d.abreviatura,
                             'CI',
                             d.abreviatura,
                             'RUC',
                             d.abreviatura,
                             'CRP',
                             d.abreviatura,
                             'CRC') Tipo_Ident,
                      p.nro_documento Nro_Ident,
                      to_char(c.fec_nacimiento, 'YYYYMMDD') Fecha_Nac,
                      trunc((nvl(a.fec_vencimiento, sysdate) - a.fec_inicio) / 365) Plazo,
                      a.mto_multa,
                      'F' Tipo_Per,
                      a.cod_persona,
                      a.nro_orden
        from ge_per_inhibidas  a,
             ba_personas       p,
             ba_per_fisicas    c,
             ba_tip_documentos d
       where a.cod_persona = p.cod_persona
         and a.estado = 'I'
         and nvl(a.situacion,'P') = 'P'
         and p.tipo = 'F'
         and p.cod_persona = c.cod_persona
         and p.cod_tip_documento = d.cod_tip_documento
         and FUG_OBT_FEC_HABIL(a.fec_inicio, 2) <= v_fec_proceso
         and INSTR(v_causa,','||a.cod_causa||',') > 0
      union all
      Select distinct '006' Tipo_formulario,
                      '0000' Sucursal,
                      to_char(a.fec_inicio, 'YYYYMMDD') Fecha_Emision,
                      ' ' Apellido,
                      j.raz_social Nombre,
                      decode(d.abreviatura,
                             'CI',
                             d.abreviatura,
                             'RUC',
                             d.abreviatura,
                             'CRP',
                             d.abreviatura,
                             'CRC') Tipo_Ident,
                      p.nro_documento Nro_Ident,
                      to_char(j.fec_apertura, 'YYYYMMDD') Fecha_Nac,
                      trunc((nvl(a.fec_vencimiento, sysdate) - a.fec_inicio) / 365) Plazo,
                      a.mto_multa,
                      'J' Tipo_Per,
                      a.cod_persona,
                      a.nro_orden
        from ge_per_inhibidas  a,
             ba_personas       p,
             ba_per_juridicas  j,
             ba_tip_documentos d
       where a.cod_persona = p.cod_persona
         and a.estado = 'I'
         and nvl(a.situacion,'P') = 'P'
         and p.tipo = 'J'
         and p.cod_persona = j.cod_persona
         and p.cod_tip_documento = d.cod_tip_documento
         and FUG_OBT_FEC_HABIL(a.fec_inicio, 2) <= v_fec_proceso
         and INSTR(v_causa,','||a.cod_causa||',') > 0;
  BEGIN
    --Genero el archivo ascii
    IF p_fecha IS NOT NULL THEN
      v_fec_proceso := p_fecha;
    ELSE
      v_fec_proceso := pag_cal.fu_obt_fec_actual(4);
    END IF;
    v_directorio := fug_obt_pardinamico('DIR_REP_FTP');
    --Verifico la existencia de registros
    BEGIN
      SELECT cod_entidad
        INTO v_cod_entidad
        FROM ge_par_generales
       WHERE rownum = 1;
    EXCEPTION
      WHEN OTHERS THEN
        raise_application_error(-20000,
                                'No existen parametros generales de la Entidad definidos');
    END;
    IF utl_file.is_open(v_archivo) THEN
      utl_file.fclose(v_archivo);
    END IF;
    Begin
      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := 1;
    end;
    ----------------------- PROCESAR ARCHIVO  ASCII ------------------------------
    v_nom_ascii := 'IC-' || v_cod_entidad || '-' ||
                   to_char(v_fec_proceso, 'YYYYMMDD') || '.TXT';
    v_archivo   := utl_file.fopen(v_directorio, v_nom_ascii, 'w');
    --ESCRIBIR EL ARCHIVO ASCII
    SELECT COUNT(*)
      INTO v_can_tot_reg
      from ge_per_inhibidas a
     where a.estado = 'I'
       and nvl(a.situacion,'P') = 'P'
       and (a.fec_inicio + 2) < v_fec_proceso
       and INSTR(v_causa,','||a.cod_causa||',') > 0;
    --Escribe la cabecera
    v_lin_datos := rpad('INHAB_CTAS', 10, ' ') ||
                   to_char(v_fec_proceso, 'YYYYMMDD') || v_cod_entidad || '0' ||
                   lpad(to_char(v_can_tot_reg), 6, '0');
    utl_file.put_line(v_archivo, v_lin_datos);
    --Escribe los detalles del archivo
    FOR arc IN c_archivo LOOP
      -- Asigna el causal y el plazo segun el calculo de fecha de vencimiento
      if arc.plazo > 1 then
        v_plazo      := 3;
        v_cod_causal := 13;
      else
        v_plazo      := 1;
        v_cod_causal := 10;
      end if;
      -- Comienza a cargar la variable
      v_lin_datos := NULL;
      v_can_reg   := v_can_reg + 1;
      v_lin_datos := v_lin_datos || lpad(trim(arc.tipo_formulario), 3, '0');
      v_lin_datos := v_lin_datos || lpad(trim(arc.sucursal), 4, '0');
      v_lin_datos := v_lin_datos || lpad(TRIM(arc.fecha_emision), 8, ' ');
      v_lin_datos := v_lin_datos ||
                     rpad(nvl(TRIM(arc.apellido), ' '), 100, ' ');
      v_lin_datos := v_lin_datos ||
                     rpad(nvl(TRIM(arc.nombre), ' '), 255, ' ');
      v_lin_datos := v_lin_datos ||
                     rpad(nvl(TRIM(arc.tipo_ident), ' '), 3, ' ');
      v_lin_datos := v_lin_datos ||
                     lpad(nvl(TRIM(arc.nro_ident), ' '), 30, ' ');
      v_lin_datos := v_lin_datos ||
                     lpad(nvl(TRIM(arc.fecha_nac), ' '), 8, ' ');
      v_lin_datos := v_lin_datos || lpad(TRIM(v_cod_causal), 2, '0');
      v_lin_datos := v_lin_datos || lpad(TRIM(v_plazo), 2, '0');
      v_lin_datos := v_lin_datos ||
                     lpad(TRIM(nvl(arc.mto_multa, 0)), 17, '0');
      v_lin_datos := v_lin_datos || lpad(TRIM(arc.tipo_per), 1);
      v_lin_datos := v_lin_datos || lpad(TRIM(v_can_reg), 6, '0');
      utl_file.put_line(v_archivo, v_lin_datos);
      -- Actualiza la situación del registro agregado
      update ge_per_inhibidas i
         set i.situacion = 'E'
       where i.cod_persona = arc.cod_persona
         and i.nro_orden = arc.nro_orden;
    END LOOP;
    utl_file.fclose(v_archivo);
    --Envio del archivo por FTP
    v_hini_ftp := to_char(sysdate,'hh24:mi:ss');
    -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
    v_respuesta := pa_file_ftp.fu_put_ascii(v_ip, v_port, v_user,
                                            v_pass, v_directorio,
                                            v_nom_ascii, v_nom_ascii);
  
    v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');
  
    if v_respuesta = 'OK' then  --archivo enviado por ftp
       null;
    else  -- error al enviar archivo por ftp
      -- insertamos el error del envio al directorio compartido
      insert into ge_ra_log_ftp
       (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
      values
       (sysdate, v_nom_ascii, v_respuesta, v_hini_ftp, v_hfin_ftp);
    end if;
 
  EXCEPTION
    WHEN no_data_found THEN
      --- Fin del archivo
      utl_file.fclose(v_archivo);
    WHEN utl_file.invalid_path THEN
      utl_file.fclose(v_archivo);
      raise_application_error(-20000, 'Directorio invalido');
    WHEN utl_file.invalid_mode THEN
      utl_file.fclose(v_archivo);
      raise_application_error(-20000, 'Modo invalido');
    WHEN utl_file.invalid_filehandle THEN
      utl_file.fclose(v_archivo);
      raise_application_error(-20000, 'Invalida Filehandle');
    WHEN utl_file.invalid_operation THEN
      --- Fin del archivo
      utl_file.fclose(v_archivo);
    WHEN utl_file.read_error THEN
      utl_file.fclose(v_archivo);
      raise_application_error(-20000, 'Lectura errada');
    WHEN utl_file.write_error THEN
      utl_file.fclose(v_archivo);
      raise_application_error(-20000, 'Escritura errada');
    WHEN utl_file.internal_error THEN
      utl_file.fclose(v_archivo);
      raise_application_error(-20000, 'Error interno');
  END;

  -- OMM 07/12/2011 Proceso que Genera archivo de Personas Rehabilitadas para envio a BCP
  PROCEDURE PR_GEN_REHABILITADAS(p_fecha IN DATE DEFAULT NULL) IS
    v_nom_ascii   VARCHAR2(30) DEFAULT '';
    v_directorio  VARCHAR2(100) DEFAULT '';
    v_lin_datos   VARCHAR2(500) := NULL;
    v_can_tot_reg NUMBER(6) DEFAULT 0;
    v_can_reg     NUMBER(6) DEFAULT 0;
    v_archivo     utl_file.file_type;
    v_fec_proceso ge_calendarios.fec_actual%TYPE;
    v_cod_entidad ge_par_generales.cod_entidad%TYPE;
    -- Variables para FTP
    v_ip          VARCHAR2(100) := fug_obt_pardinamico('DIR_SVR_REP_ARCHIVOS');
    v_port        VARCHAR2(100) := '121';
    v_user        VARCHAR2(100) := fug_obt_pardinamico('USU_FTP_REP_ARCHIVOS');
    v_pass        VARCHAR2(100) := fug_obt_pardinamico('PAS_FTP_REP_ARCHIVOS');
    v_respuesta   VARCHAR2(4000);
    v_hini_ftp    ge_ra_log_ftp.hor_inicio%type;
    v_hfin_ftp    ge_ra_log_ftp.hor_fin%type;
    
    v_causa       VARCHAR2(100) := fug_obt_pardinamico('COD_CAU_INH_BLO_CTA');
    
    --CURSOR PRINCIPAL DE LA TABLA EN DONDE SE INSERTAN LOS REGISTROS DIARIOS
    CURSOR c_archivo IS
      Select distinct '007' Tipo_formulario,
                      '0000' Sucursal,
                      to_char(a.fec_inicio, 'YYYYMMDD') Fecha_Emision,
                      c.pri_apellido || ' ' || c.seg_apellido Apellido,
                      c.pri_nombre || ' ' || c.seg_nombre Nombre,
                      decode(d.abreviatura,
                             'CI',
                             d.abreviatura,
                             'RUC',
                             d.abreviatura,
                             'CRP',
                             d.abreviatura,
                             'CRC') Tipo_Ident,
                      p.nro_documento Nro_Ident,
                      to_char(c.fec_nacimiento, 'YYYYMMDD') Fecha_Nac,
                      a.cod_rehabilitacion Causal,
                      'F' Tipo_Per,
                      a.cod_persona,
                      a.nro_orden
        from ge_per_inhibidas  a,
             ba_personas       p,
             ba_per_fisicas    c,
             ba_tip_documentos d
       where a.cod_persona = p.cod_persona
         and a.estado = 'D'
         and a.situacion = 'E'
         and p.tipo = 'F'
         and p.cod_persona = c.cod_persona
         and p.cod_tip_documento = d.cod_tip_documento
         and a.fec_rehabilitacion < v_fec_proceso
         and INSTR(v_causa,','||a.cod_causa||',') > 0
      union all
      Select distinct '007' Tipo_formulario,
                      '0000' Sucursal,
                      to_char(a.fec_inicio, 'YYYYMMDD') Fecha_Emision,
                      ' ' Apellido,
                      j.raz_social Nombre,
                      decode(d.abreviatura,
                             'CI',
                             d.abreviatura,
                             'RUC',
                             d.abreviatura,
                             'CRP',
                             d.abreviatura,
                             'CRC') Tipo_Ident,
                      p.nro_documento Nro_Ident,
                      to_char(j.fec_apertura, 'YYYYMMDD') Fecha_Nac,
                      a.cod_rehabilitacion Causal,
                      'J' Tipo_Per,
                      a.cod_persona,
                      a.nro_orden
        from ge_per_inhibidas  a,
             ba_personas       p,
             ba_per_juridicas  j,
             ba_tip_documentos d
       where a.cod_persona = p.cod_persona
         and a.estado = 'D'
         and a.situacion = 'E'
         and p.tipo = 'J'
         and p.cod_persona = j.cod_persona
         and p.cod_tip_documento = d.cod_tip_documento
         and a.fec_rehabilitacion < v_fec_proceso
         and INSTR(v_causa,','||a.cod_causa||',') > 0;
  BEGIN
    --Genero el archivo ascii
    IF p_fecha IS NOT NULL THEN
      v_fec_proceso := p_fecha;
    ELSE
      v_fec_proceso := pag_cal.fu_obt_fec_actual(4);
    END IF;
    v_directorio := fug_obt_pardinamico('DIR_REP_FTP');
    --Verifico la existencia de registros
    BEGIN
      SELECT cod_entidad
        INTO v_cod_entidad
        FROM ge_par_generales
       WHERE rownum = 1;
    EXCEPTION
      WHEN OTHERS THEN
        raise_application_error(-20000,
                                'No existen parametros generales de la Entidad definidos');
    END;
    IF utl_file.is_open(v_archivo) THEN
      utl_file.fclose(v_archivo);
    END IF;
    Begin
      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := 1;
    end;
    ----------------------- PROCESAR ARCHIVO  ASCII ------------------------------
    v_nom_ascii := 'RC-' || v_cod_entidad || '-' ||
                   to_char(v_fec_proceso, 'YYYYMMDD') || '.TXT';
    v_archivo   := utl_file.fopen(v_directorio, v_nom_ascii, 'w');
    --ESCRIBIR EL ARCHIVO ASCII
    SELECT COUNT(*)
      INTO v_can_tot_reg
      from ge_per_inhibidas a
     where a.estado = 'D'
       and a.situacion = 'E'
       and a.fec_rehabilitacion < v_fec_proceso;
    --Escribe la cabecera
    v_lin_datos := rpad('REHAB_CTAS', 10, ' ') ||
                   to_char(v_fec_proceso, 'YYYYMMDD') || v_cod_entidad || '0' ||
                   lpad(to_char(v_can_tot_reg), 6, '0');
    utl_file.put_line(v_archivo, v_lin_datos);
    --Escribe los detalles del archivo
    FOR arc IN c_archivo LOOP
      v_lin_datos := NULL;
      v_can_reg   := v_can_reg + 1;
      v_lin_datos := v_lin_datos || lpad(trim(arc.tipo_formulario), 3, '0');
      v_lin_datos := v_lin_datos || lpad(trim(arc.sucursal), 4, '0');
      v_lin_datos := v_lin_datos || lpad(TRIM(arc.fecha_emision), 8, ' ');
      v_lin_datos := v_lin_datos ||
                     rpad(nvl(TRIM(arc.apellido), ' '), 100, ' ');
      v_lin_datos := v_lin_datos ||
                     rpad(nvl(TRIM(arc.nombre), ' '), 255, ' ');
      v_lin_datos := v_lin_datos ||
                     rpad(nvl(TRIM(arc.tipo_ident), ' '), 3, ' ');
      v_lin_datos := v_lin_datos ||
                     lpad(nvl(TRIM(arc.nro_ident), ' '), 30, ' ');
      v_lin_datos := v_lin_datos ||
                     lpad(nvl(TRIM(arc.fecha_nac), ' '), 8, ' ');
      v_lin_datos := v_lin_datos || lpad(TRIM(arc.causal), 3, '0');
      v_lin_datos := v_lin_datos || lpad(TRIM(arc.tipo_per), 1);
      v_lin_datos := v_lin_datos || lpad(TRIM(v_can_reg), 6, '0');
      utl_file.put_line(v_archivo, v_lin_datos);
      -- Actualiza la situación del registro agregado
      update ge_per_inhibidas i
         set i.situacion = 'R'
       where i.cod_persona = arc.cod_persona
         and i.nro_orden = arc.nro_orden;
    END LOOP;
    utl_file.fclose(v_archivo);
    --Envio del archivo por FTP
    v_hini_ftp := to_char(sysdate,'hh24:mi:ss');
    -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
    v_respuesta := pa_file_ftp.fu_put_ascii(v_ip, v_port, v_user,
                                            v_pass, v_directorio,
                                            v_nom_ascii, v_nom_ascii);
  
    v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');
  
    if v_respuesta = 'OK' then  --archivo enviado por ftp
       null;
    else  -- error al enviar archivo por ftp
      -- insertamos el error del envio al directorio compartido
      insert into ge_ra_log_ftp
       (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
      values
       (sysdate, v_nom_ascii, v_respuesta, v_hini_ftp, v_hfin_ftp);
    end if;    
  EXCEPTION
    WHEN no_data_found THEN
      --- Fin del archivo
      utl_file.fclose(v_archivo);
    WHEN utl_file.invalid_path THEN
      utl_file.fclose(v_archivo);
      raise_application_error(-20000, 'Directorio invalido');
    WHEN utl_file.invalid_mode THEN
      utl_file.fclose(v_archivo);
      raise_application_error(-20000, 'Modo invalido');
    WHEN utl_file.invalid_filehandle THEN
      utl_file.fclose(v_archivo);
      raise_application_error(-20000, 'Invalida Filehandle');
    WHEN utl_file.invalid_operation THEN
      --- Fin del archivo
      utl_file.fclose(v_archivo);
    WHEN utl_file.read_error THEN
      utl_file.fclose(v_archivo);
      raise_application_error(-20000, 'Lectura errada');
    WHEN utl_file.write_error THEN
      utl_file.fclose(v_archivo);
      raise_application_error(-20000, 'Escritura errada');
    WHEN utl_file.internal_error THEN
      utl_file.fclose(v_archivo);
      raise_application_error(-20000, 'Error interno');
  END;
  PROCEDURE PR_GEN_FDG_VALIDACION IS
    v_fec_actual VARCHAR2(10) := fug_obt_pardinamico('FEC_PRO_FDG');
  BEGIN
    --raise_application_error(-20000, 'Error interno');
    --Se borra datos de la tabla SB_FDG_VALIDACIONES
    IF v_fec_actual IS NULL THEN
      raise_application_error(-20000,
                              'Parámetro FEC_PRO_FDG no debe ser nulo.');
    END IF;
    DELETE sb_fdg_validaciones a WHERE a.fecha = v_fec_actual;
    -- Validación de Cantidades
    /**Se verifica si existen datos en la tabla de Saldos de Depósitos que no son menores a 1.
    si existen datos se insertan en sb_fdg_validaciones*/
    INSERT INTO sb_fdg_validaciones
      (fecha, nro_cuenta, cod_persona, mensaje, nom_tabla)
      SELECT v_fec_actual,
             a.nro_cuenta cuenta,
             NULL persona,
             'Cantidad de Titulares de la tabla de Saldos de Depósitos no debe ser menor a 1.' mensaje,
             'sb_fdg_depositos' tabla
        FROM sb_fdg_depositos a
       WHERE a.can_titulares < 1
         AND a.fecha = v_fec_actual;
    /**Se verifica si existen datos de Titulares en la tabla de Saldos de Deudas que no son menor a 1.
    si existen datos se insertan en sb_fdg_validaciones*/
    INSERT INTO sb_fdg_validaciones
      (fecha, nro_cuenta, cod_persona, mensaje, nom_tabla)
      SELECT v_fec_actual,
             a.nro_cuenta cuenta,
             NULL persona,
             'Cantidad de Titulares de la tabla de Saldos de Deudas no debe ser menor a 1.' mensaje,
             'sb_fdg_deudas' tabla
        FROM sb_fdg_deudas a
       WHERE a.can_titulares < 1
         AND a.fecha = v_fec_actual;
    -- Validación de Cuentas
    /**Se verifica si existe deudas del titular registradas en la tabla saldos de deudas
    si existen datos se insertan en sb_fdg_validaciones*/
    INSERT INTO sb_fdg_validaciones
      (fecha, nro_cuenta, cod_persona, mensaje, nom_tabla)
      SELECT v_fec_actual,
             a.nro_cuenta cuenta,
             a.cod_persona persona,
             'Los datos de la tabla de Deuda por Titular deben existir en la tabla de Saldos de Deudas validando por Número de Cuenta.' mensaje,
             'sb_fdg_deu_personas' tabla
        FROM sb_fdg_deu_personas a
       WHERE NOT EXISTS (SELECT 1
                FROM sb_fdg_deudas m
               WHERE m.nro_cuenta = a.nro_cuenta
                 AND m.fecha = v_fec_actual)
         AND a.fecha = v_fec_actual;
    /**Se verifica que los datos de la tabla Saldos de Deudas existan en la tabla deuda por titular
    y se insertan en sb_fdg_validaciones*/
    INSERT INTO sb_fdg_validaciones
      (fecha, nro_cuenta, cod_persona, mensaje, nom_tabla)
      SELECT v_fec_actual,
             a.nro_cuenta cuenta,
             NULL persona,
             'Los datos de la tabla de Saldos de Deudas deben existir en la tabla de Deuda por Titular validando por Número de Cuenta.' mensaje,
             'sb_fdg_deudas' tabla
        FROM sb_fdg_deudas a
       WHERE NOT EXISTS (SELECT 1
                FROM sb_fdg_deu_personas m
               WHERE m.nro_cuenta = a.nro_cuenta
                 AND m.fecha = v_fec_actual)
         AND a.fecha = v_fec_actual;
    /**Se verifica que los datos de la tabla Depositos por titular existan en la tabla Saldos de Depositos
    y se insertan en sb_fdg_validaciones*/
    INSERT INTO sb_fdg_validaciones
      (fecha, nro_cuenta, cod_persona, mensaje, nom_tabla)
      SELECT v_fec_actual,
             a.nro_cuenta cuenta,
             a.cod_persona persona,
             'Los datos de la tabla de Depósitos por Titular deben existir en la tabla de Saldos de Depósitos validando por Número de Cuenta.' mensaje,
             'sb_fdg_dep_personas' tabla
        FROM sb_fdg_dep_personas a
       WHERE NOT EXISTS (SELECT 1
                FROM sb_fdg_depositos m
               WHERE m.nro_cuenta = a.nro_cuenta
                 AND m.fecha = v_fec_actual)
         AND a.fecha = v_fec_actual;
    /**Se verifica que los datos de la tabla Saldos de Depositos existan en la tabla Depositos por titular
    y se insertan en sb_fdg_validaciones*/
    INSERT INTO sb_fdg_validaciones
      (fecha, nro_cuenta, cod_persona, mensaje, nom_tabla)
      SELECT v_fec_actual,
             a.nro_cuenta cuenta,
             NULL persona,
             'Los datos de la tabla de Saldos de Depósitos deben existir en la tabla de Depósitos por Titular validando por Número de Cuenta.' mensaje,
             'sb_fdg_depositos' tabla
        FROM sb_fdg_depositos a
       WHERE NOT EXISTS (SELECT 1
                FROM sb_fdg_dep_personas m
               WHERE m.nro_cuenta = a.nro_cuenta
                 AND m.fecha = v_fec_actual)
         AND a.fecha = v_fec_actual;
    --Validación de Duplicaciones
    /**Se verifica que no exista más de un registro para un mismo número de Cuenta en la tabla de
    Saldos de Depósitos y se insertan en sb_fdg_validaciones.*/
    INSERT INTO sb_fdg_validaciones
      (fecha, nro_cuenta, cod_persona, mensaje, nom_tabla)
      SELECT v_fec_actual,
             a.nro_cuenta cuenta,
             'cant:' || COUNT(1) persona,
             'No puede existir más de un registro para un mismo número de Cuenta en la tabla de Saldos de Depósitos.' mensaje,
             'sb_fdg_depositos' tabla
        FROM sb_fdg_depositos a
       WHERE a.fecha = v_fec_actual
       GROUP BY a.nro_cuenta
      HAVING COUNT(1) > 1;
    /**Se verifica que no exista más de un registro para un mismo número de Cuenta en la tabla de
    Saldos de Deudas y se insertan en sb_fdg_validaciones.*/
    INSERT INTO sb_fdg_validaciones
      (fecha, nro_cuenta, cod_persona, mensaje, nom_tabla)
      SELECT v_fec_actual,
             a.nro_cuenta cuenta,
             'cant:' || COUNT(1) persona,
             'No puede existir más de un registro para un mismo número de Cuenta en la tabla de Saldos de Deudas.' mensaje,
             'sb_fdg_deudas' tabla
        FROM sb_fdg_deudas a
       WHERE a.fecha = v_fec_actual
       GROUP BY a.nro_cuenta
      HAVING COUNT(1) > 1;
    --Validación de Montos
    /**Se verifica que el valor del Capital no sea negativo en la tabla de Saldos de Depósitos*/
    INSERT INTO sb_fdg_validaciones
      (fecha, nro_cuenta, cod_persona, mensaje, nom_tabla)
      SELECT v_fec_actual,
             a.nro_cuenta cuenta,
             NULL persona,
             'El valor del Capital no puede ser  negativo en la tabla de Saldos de Depósitos.' mensaje,
             'sb_fdg_depositos' tabla
        FROM sb_fdg_depositos a
       WHERE a.capital < 0
         AND a.fecha = v_fec_actual;
    /**Se verifica que el valor del Interés Devengado no sea negativo en la tabla de Saldos de Depósitos*/
    INSERT INTO sb_fdg_validaciones
      (fecha, nro_cuenta, cod_persona, mensaje, nom_tabla)
      SELECT v_fec_actual,
             a.nro_cuenta cuenta,
             NULL persona,
             'El valor del Interés Devengado no puede ser negativo en la tabla de Saldos de Depósitos.' mensaje,
             'sb_fdg_depositos' tabla
        FROM sb_fdg_depositos a
       WHERE a.int_devengado < 0
         AND a.fecha = v_fec_actual;
    /**Se verifica que el valor del Monto Total no sea negativo en la tabla de Saldos de Depósitos*/
    INSERT INTO sb_fdg_validaciones
      (fecha, nro_cuenta, cod_persona, mensaje, nom_tabla)
      SELECT v_fec_actual,
             a.nro_cuenta cuenta,
             NULL persona,
             'El valor del Monto Total no puede ser negativo en la tabla de Saldos de Depósitos.' mensaje,
             'sb_fdg_depositos' tabla
        FROM sb_fdg_depositos a
       WHERE a.total < 0
         AND a.fecha = v_fec_actual;
    /**Se verifica que el valor del Capital no sea negativo en la tabla de Saldos de Deudas*/
    INSERT INTO sb_fdg_validaciones
      (fecha, nro_cuenta, cod_persona, mensaje, nom_tabla)
      SELECT v_fec_actual,
             a.nro_cuenta cuenta,
             NULL persona,
             'El valor del Capital no puede ser negativo en la tabla de Saldos de Deudas.' mensaje,
             'sb_fdg_deudas' tabla
        FROM sb_fdg_deudas a
       WHERE a.capital < 0
         AND a.fecha = v_fec_actual;
    /**Se verifica que el valor del Interés Devengado no sea negativo en la tabla de Saldos de Deudas*/
    INSERT INTO sb_fdg_validaciones
      (fecha, nro_cuenta, cod_persona, mensaje, nom_tabla)
      SELECT v_fec_actual,
             a.nro_cuenta cuenta,
             NULL persona,
             'El valor del Interés Devengado no puede ser negativo en la tabla de Saldos de Deudas.' mensaje,
             'sb_fdg_deudas' tabla
        FROM sb_fdg_deudas a
       WHERE a.int_devengado < 0
         AND a.fecha = v_fec_actual;
    /**Se verifica que el valor del Monto Total no sea negativo en la tabla de Saldos de Deudas*/
    INSERT INTO sb_fdg_validaciones
      (fecha, nro_cuenta, cod_persona, mensaje, nom_tabla)
      SELECT v_fec_actual,
             a.nro_cuenta cuenta,
             NULL persona,
             'El valor del Monto Total no puede ser negativo en la tabla de Saldos de Deudas.' mensaje,
             'sb_fdg_deudas' tabla
        FROM sb_fdg_deudas a
       WHERE a.total < 0
         AND a.fecha = v_fec_actual;
    /**Se verifica que el valor del Capital moneda Extranjera no sea negativo en la tabla de Saldos de Depósitos*/
    INSERT INTO sb_fdg_validaciones
      (fecha, nro_cuenta, cod_persona, mensaje, nom_tabla)
      SELECT v_fec_actual,
             a.nro_cuenta cuenta,
             NULL persona,
             'El valor del Capital moneda Extranjera no puede ser negativo en la tabla de Saldos de Depósitos.' mensaje,
             'sb_fdg_depositos' tabla
        FROM sb_fdg_depositos a
       WHERE a.capital_ext < 0
         AND a.fecha = v_fec_actual;
    /**Se verifica que el valor del Interés Devengado moneda Extranjera no sea negativo en la tabla Saldos de Depósitos*/
    INSERT INTO sb_fdg_validaciones
      (fecha, nro_cuenta, cod_persona, mensaje, nom_tabla)
      SELECT v_fec_actual,
             a.nro_cuenta cuenta,
             NULL persona,
             'El valor del Interés Devengado moneda Extranjera no puede ser negativo en la tabla Saldos de Depósitos.' mensaje,
             'sb_fdg_depositos' tabla
        FROM sb_fdg_depositos a
       WHERE a.int_devengado_ext < 0
         AND a.fecha = v_fec_actual;
    /**Se verifica que el valor del Capital moneda Extranjera no sea negativo en la tabla de Saldos de Deudas*/
    INSERT INTO sb_fdg_validaciones
      (fecha, nro_cuenta, cod_persona, mensaje, nom_tabla)
      SELECT v_fec_actual,
             a.nro_cuenta cuenta,
             NULL persona,
             'El valor del Capital moneda Extranjera no puede ser negativo en la tabla de Saldos de Deudas.' mensaje,
             'sb_fdg_deudas' tabla
        FROM sb_fdg_deudas a
       WHERE a.capital_ext < 0
         AND a.fecha = v_fec_actual;
    /**Se verifica que el valor del Interés Devengado moneda Extranjera no sea negativo en la tabla de Saldos de Deudas*/
    INSERT INTO sb_fdg_validaciones
      (fecha, nro_cuenta, cod_persona, mensaje, nom_tabla)
      SELECT v_fec_actual,
             a.nro_cuenta cuenta,
             NULL persona,
             'El valor del Interés Devengado moneda Extranjera no puede ser negativo en la tabla de Saldos de Deudas.' mensaje,
             'sb_fdg_deudas' tabla
        FROM sb_fdg_deudas a
       WHERE a.int_devengado_ext < 0
         AND a.fecha = v_fec_actual;
    /**Se verifica que el valor del Monto Total moneda Extranjera no sea negativo en la tabla de Saldos de Deudas*/
    INSERT INTO sb_fdg_validaciones
      (fecha, nro_cuenta, cod_persona, mensaje, nom_tabla)
      SELECT v_fec_actual,
             a.nro_cuenta cuenta,
             NULL persona,
             'El valor del Monto Total moneda Extranjera no puede ser negativo en la tabla de Saldos de Deudas.' mensaje,
             'sb_fdg_deudas' tabla
        FROM sb_fdg_deudas a
       WHERE a.total_ext < 0
         AND a.fecha = v_fec_actual;
    --Validación de Personas
    /**Se verifica que los datos de la tabla de Depósitos por Titular existan en la tabla de Datos de Personas Físicas o Jurídicas*/
    INSERT INTO sb_fdg_validaciones
      (fecha, nro_cuenta, cod_persona, mensaje, nom_tabla)
      SELECT v_fec_actual,
             a.nro_cuenta cuenta,
             a.cod_persona persona,
             'Los datos de la tabla de Depósitos por Titular deben existir en la tabla de Datos de Personas Físicas o Jurídicas validando por Código de Persona.' mensaje,
             'sb_fdg_dep_personas' tabla
        FROM sb_fdg_dep_personas a
       WHERE NOT EXISTS (SELECT 1
                FROM sb_fdg_personas m
               WHERE m.cod_persona = a.cod_persona
                 AND m.fecha = v_fec_actual)
         AND a.fecha = v_fec_actual;
    /**Se verifica que los datos de la tabla de Deuda por Titular existan en la tabla de Datos de Personas Físicas o Jurídicas*/
    INSERT INTO sb_fdg_validaciones
      (fecha, nro_cuenta, cod_persona, mensaje, nom_tabla)
      SELECT v_fec_actual,
             a.nro_cuenta cuenta,
             a.cod_persona persona,
             'Los datos de la tabla de Deuda por Titular deben existir en la tabla de Datos de Personas Físicas o Jurídicas validando por Código de Persona.' mensaje,
             'sb_fdg_deu_personas' tabla
        FROM sb_fdg_deu_personas a
       WHERE NOT EXISTS (SELECT 1
                FROM sb_fdg_personas m
               WHERE m.cod_persona = a.cod_persona
                 AND m.fecha = v_fec_actual)
         AND a.fecha = v_fec_actual;

    --Borra la tabla sb_fdg_datos para insertar la cantidad de registros
    DELETE sb_fdg_datos WHERE fecha = v_fec_actual;
    --Personas FDG:
    INSERT INTO sb_fdg_datos
      (ref_archivo, can_registros, fecha)
    VALUES
      ('PS',
       (SELECT COUNT(1) FROM sb_fdg_personas WHERE fecha = v_fec_actual),
       v_fec_actual);
    --Depósitos FDG:
    INSERT INTO sb_fdg_datos
      (ref_archivo, can_registros, fecha)
    VALUES
      ('DP',
       (SELECT COUNT(1) FROM sb_fdg_depositos WHERE fecha = v_fec_actual),
       v_fec_actual);
    --Personas ¿ Depósitos FDG:
    INSERT INTO sb_fdg_datos
      (ref_archivo, can_registros, fecha)
    VALUES
      ('PD',
       (SELECT COUNT(1) FROM sb_fdg_dep_personas WHERE fecha = v_fec_actual),
       v_fec_actual);
    --Deudas FDG:
    INSERT INTO sb_fdg_datos
      (ref_archivo, can_registros, fecha)
    VALUES
      ('DU',
       (SELECT COUNT(1) FROM sb_fdg_deudas WHERE fecha = v_fec_actual),
       v_fec_actual);
    --Personas ¿ Deudas FDG:
    INSERT INTO sb_fdg_datos
      (ref_archivo, can_registros, fecha)
    VALUES
      ('PU',
       (SELECT COUNT(1) FROM sb_fdg_deu_personas WHERE fecha = v_fec_actual),
       v_fec_actual);
    --Valición de las cantidad entre DP y PD:
    INSERT INTO sb_fdg_validaciones
      (fecha, nro_cuenta, cod_persona, mensaje, nom_tabla)
      SELECT v_fec_actual,
             'cant:' || a.can_registros cuenta,
             'cant:' || b.can_registros persona,
             'Cantidad de Depósitos (DP) no coincide con Personas-Depósitos (PD).' mensaje,
             'sb_fdg_depositos - sb_fdg_dep_personas' tabla
        FROM sb_fdg_datos a, sb_fdg_datos b
       WHERE a.can_registros <> b.can_registros
         AND a.ref_archivo = 'DP'
         AND b.ref_archivo = 'PD'
         AND a.fecha = v_fec_actual
         AND b.fecha = v_fec_actual;
    --Valición de las cantidad entre DU y PU:
    INSERT INTO sb_fdg_validaciones
      (fecha, nro_cuenta, cod_persona, mensaje, nom_tabla)
      SELECT v_fec_actual,
             'cant:' || a.can_registros cuenta,
             'cant:' || b.can_registros persona,
             'Cantidad de Deudas (DU) no coincide con Personas-Deudas (PU).' mensaje,
             'sb_fdg_deudas - sb_fdg_deu_personas' tabla
        FROM sb_fdg_datos a, sb_fdg_datos b
       WHERE a.can_registros <> b.can_registros
         AND a.ref_archivo = 'DU'
         AND b.ref_archivo = 'PU'
         AND a.fecha = v_fec_actual
         AND b.fecha = v_fec_actual;
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE <= -20000 THEN
        RAISE;
      ELSE
        raise_application_error(-20000,
                                'en pr_gen_fdg_validacion ' || SQLERRM);
      END IF;
  END;
END PAS_BCP;
