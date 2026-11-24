CREATE OR REPLACE VIEW IT.GV_SAL_PASIVO AS
SELECT --'2023-12-28' as FECHA_PROCESO,
     to_char(pag_cal.fu_obt_fec_actual(6), 'yyyy-mm-dd') as FECHA_PROCESO,
        d.nro_cuenta,
        s.cod_persona,
        bf.tipo,
        bf.cod_tip_documento,
        bf.nro_documento,
        BF.nom_completo as nombre,
        c.cod_modulo,
        MC.DESCRIPCION des_modulo,
        c.cod_modalidad cod_modalidad,
        modalidad.descripcion as des_modalidad,
        cta.cod_sub_modalidad as cod_sub_modalidad,
        sub_m.descripcion as des_sub_modalidad,
        c.cod_oficina,
        ofi.descripcion as des_ofi,
        c.cod_moneda,
        NVL(COT.VAL_CONVERSION,1) as cotizacion,
        tip_saldo,
        CASE WHEN tip_saldo = 'A' THEN 'A DEVENGAR'
             WHEN tip_saldo = 'C' THEN 'CAPITAL'
             WHEN tip_saldo = 'D' THEN 'DEVENGADO'
             WHEN tip_saldo = 'F' THEN 'PREVISIONES ESPECIALES'
             WHEN tip_saldo = 'I' THEN 'INTERES'
             WHEN tip_saldo = 'S' THEN 'INTERES EN SUSPENSO'
             WHEN tip_saldo = 'V' THEN 'PREVISIONES'
        END AS TIPOSALDO,
        c.situacion,
        est_c.descripcion as estado,
        p.fec_apertura as fec_apertura,
        p.fec_vencimiento as fec_vencimiento,
        p.val_tasa,
        p.cod_tasa,
        tas.descripcion as des_tasa,
        c.cod_rubro,
        rub.descripcion,
        sal_actual as sal_actual,
        round(sal_actual *(NVL(COT.VAL_CONVERSION,1))) AS saldo_gs,
        CL.CAT_RIESGO,
        CL.CAT_SUBJETIVA,
        CL.CAT_AUTOMATICA,
        CL.CAT_RENOVACIONES,
        CL.COD_SEG_CLIENTE,
        gsc.DESCRIPCION AS DES_SEG_CLIENTE,
        CL.COD_SEC_CONTABLE,
        SE.DESCRIPCION AS DES_SEC_CONTABLE,
        CL.COD_TIP_DEUDOR,
        DE.DESCRIPCION AS DES_TIP_DEUDOR,
        BF.cod_actividad AS COD_ACTIVIDAD,
        ga.DESCRIPCION AS DES_ACTIVIDAD,
        PR.COD_RUB_ECONOMICO AS COD_RUB_ECONOMICO,
        GU.descripcion AS DES_RUB_ECONOMICO,
        PR.CAN_CUOTAS AS CAN_CUOTAS,
        PR.CAN_CUO_PAGADAS AS CAN_CUO_PAGADAS,
        PR.DIA_ATRASO AS DIAS_ATRASO
FROM cb_sal_inventarios_his c
    INNER JOIN cb_sal_inventarios_det_his d
        ON d.nro_referencia = c.nro_referencia
        AND d.fecha = c.fecha
    INNER JOIN  ge_cta_clientes s
        ON s.nro_cuenta = d.nro_cuenta
        AND s.relacion = 'P'
    INNER JOIN  ge_cuentas p
        ON  p.nro_cuenta = s.nro_cuenta
    INNER JOIN  ge_clientes cl
        ON s.cod_persona = cl.cod_persona
    LEFT JOIN GE_TASAS TAS
        ON TAS.COD_TASA = P.COD_TASA
    LEFT JOIN ge_sec_contables se
        ON se.cod_sec_contable = cl.cod_sec_contable
    LEFT JOIN ge_tip_deudores de
        ON de.cod_tip_deudor = cl.cod_tip_deudor
        and se.cod_sec_contable = de.cod_sec_contable
    LEFT JOIN GE_SEG_CLIENTES gsc
        ON CL.COD_SEG_CLIENTE = GSC.COD_SEG_CLIENTE
    LEFT JOIN PR_CTA_PRESTAMOS PR
        ON PR.NRO_CUENTA  = s.nro_cuenta
    LEFT JOIN GE_RUB_ECONOMICOS GU
        ON GU.COD_RUB_ECONOMICO = PR.COD_RUB_ECONOMICO
    LEFT JOIN BA_PERSONAS BF
        ON BF.COD_PERSONA  = S.COD_PERSONA
    LEFT JOIN GE_ACTIVIDADES ga
        ON ga.COD_ACTIVIDAD = BF.cod_actividad
    LEFT JOIN BA_MODULOS MC
        ON MC.COD_MODULO = c.COD_MODULO
/*
###############################
nuevos joins
###############################
*/
   LEFT JOIN ge_modalidades modalidad
        ON modalidad.cod_modulo = c.cod_modulo
        and modalidad.cod_modalidad = c.cod_modalidad
    LEFT JOIN ba_oficinas ofi
        ON ofi.cod_oficina = c.cod_oficina
    LEFT JOIN GE_COTIZACIONES COT
        ON COT.COD_MONEDA =  c.cod_moneda
        AND COT.FECHA = c.fecha
    LEFT JOIN ge_est_cuentas est_c
        ON est_c.cod_modulo = p.cod_modulo
        AND est_c.cod_modalidad = p.cod_modalidad
        AND est_c.estado = C.SITUACION
    LEFT JOIN cb_rubros rub
        ON rub.cod_rubro = c.cod_rubro
    LEFT JOIN (SELECT nro_cuenta, cod_modulo, cod_modalidad, cod_sub_modalidad
          FROM pr_cta_prestamos
          UNION
          SELECT nro_cuenta, cod_modulo, cod_modalidad, cod_sub_modalidad
          FROM ah_cta_vistas) cta
        on cta.nro_cuenta = d.nro_cuenta
    LEFT JOIN ge_sub_modalidades sub_m
        on cta.cod_modulo = sub_m.cod_modulo
        and cta.cod_modalidad = sub_m.cod_modalidad
        and cta.cod_sub_modalidad = sub_m.cod_sub_modalidad
WHERE  c.fecha = (pag_cal.fu_obt_fec_actual(6))
AND  (c.cod_modulo=3 or (c.cod_modulo=4 and sal_actual >0))
;
