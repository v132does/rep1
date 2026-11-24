CREATE OR REPLACE VIEW IT.SV_CRC_SALDOS_DET_EQV
AS 
    WITH mig AS (
        SELECT
            m.nro_cta_itgf,
            m.tip_operacion,
            m.cod_oficina,
            m.nro_ope_saldos,
            ROW_NUMBER()
            OVER(PARTITION BY m.nro_cta_itgf, m.tip_operacion, m.cod_oficina
                 ORDER BY
                     m.nro_ope_saldos DESC
            ) rn
        FROM
            it.sb_crc_cta_migrada m
    ), ofi AS (
        SELECT
            o.nro_operacion,
            o.tip_operacion,
            o.cod_oficina,
            o.cod_moneda,
            o.cod_ofi_crc,
            o.nro_registro,
            ROW_NUMBER()
            OVER(PARTITION BY o.nro_operacion,
                              o.tip_operacion,
                              o.cod_oficina,
                              o.cod_moneda
                 ORDER BY
                     nvl(o.nro_registro, 0) DESC
            ) rn
        FROM
            it.sb_crc_cam_oficina o
    )
    SELECT
        d.nro_registro,
        d.fecha,
        d.nro_formulario,
        nvl(o.cod_ofi_crc, d.cod_oficina)      AS cod_oficina_eqv,
        d.tip_operacion,
        nvl(m.nro_ope_saldos, d.nro_operacion) AS nro_operacion_eqv,
        d.con_mon_iso,
        d.fec_corte,
        d.fec_vto_cuota,
        d.fec_vto_cuo_vencida,
        d.dia_atraso,
        d.rub_con_capital,
        d.sal_capital,
        d.sal_cuo_vencida,
        d.rub_con_int_devengar,
        d.sal_int_devengar,
        d.rub_con_dev_no_cobrado,
        d.sal_int_dev_no_cobrado,
        d.rub_con_int_dev_cobrado,
        d.sal_int_dev_cobrado,
        d.rub_con_dev_suspenso,
        d.sal_int_suspenso,
        d.rub_con_contingencia,
        d.mto_contingencia,
        d.tas_efectiva,
        d.rub_con_prevision,
        d.mto_prevision,
        d.can_cuo_pagadas,
        d.cla_riesgo,
        d.ind_movimiento,
        d.est_tarjeta,
        d.mto_deu_anterior,
        d.mto_pag_mes,
        d.mto_com_mes,
        d.mto_deu_facturar,
        d.mto_cargo,
        d.mto_lin_credito
    FROM
        it.sb_crc_saldos_det d
        LEFT JOIN mig                  m ON m.nro_cta_itgf = d.nro_operacion
                           AND m.tip_operacion = d.tip_operacion
                           AND m.cod_oficina = d.cod_oficina
                           AND m.rn = 1
        LEFT JOIN ofi                  o ON o.nro_operacion = d.nro_operacion
                           AND o.tip_operacion = d.tip_operacion
                           AND o.cod_oficina = d.cod_oficina
                           AND o.cod_moneda = d.con_mon_iso
                           AND o.rn = 1;
