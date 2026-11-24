CREATE OR REPLACE FORCE VIEW IT.PV_CAT_PRESTAMOS AS
SELECT b.cod_persona,
       a.nro_cuenta,
       a.cod_modulo,
       a.cod_modalidad,
       a.cod_moneda,
       NVL(a.sal_capital,0) sal_cap_batch,
       NVL(a.dia_atraso,0) dia_atraso,
       a.estado,
       DECODE(a.estado,'I',NVL(a.sal_interes,0)+NVL(a.sal_int_adelantado,0),
       NVL( a.dev_no_cobrado,0)) dev_no_cobrado,
       a.cod_oficina,
       NVL(a.tip_renovacion,'A') tipo,
       a.mto_capital,
       a.nro_cta_renovada,
       a.cat_renovaciones,
       a.tip_destino,
       c.cod_bco_central cod_sec_credito,
       NVL(f.mto_computable,0)mto_computable,
       NVL(p.monto,0)mto_prevision,
       NVL(p.tot_pri_prevision,0)mto_tot_pri_prevision,
       f.nro_cuenta nro_cta_garantia,
       a.fec_ult_categorizacion,
       a.fec_inicio
  FROM ge_cta_clientes b,
       pr_cta_prestamos a,
       pr_sec_creditos c,
       pv_cat_gar_operaciones f,
       (SELECT pr.monto,
               pr.tot_pri_prevision,
               pr.nro_cuenta
          FROM pr_previsiones pr
         WHERE pr.fecha = (SELECT max(pv.fecha)
                             FROM pr_previsiones pv
                            WHERE pr.nro_cuenta = pv.nro_cuenta))p
  WHERE b.nro_cuenta = a.nro_cuenta
    AND NVL(a.sal_capital,0)+NVL(a.sal_int_adelantado,0)+NVL(a.sal_interes,0) > 0
    AND a.estado NOT IN ('N','I')
    --and fup_obt_tip_bono(a.cod_modalidad) = 'N' -- Comentado por ICL 20100729 --Se maneja en el modulo de mesa de dinero
    --and fup_obt_tip_letra(a.cod_modalidad) = 'N'
    --and fup_obt_tip_afd(a.cod_modalidad) = 'N'
    AND a.cod_sec_credito = c.cod_sec_credito
    AND b.relacion='P'--y principales de cuenta
    AND f.nro_cuenta(+) = a.nro_cuenta
    AND p.nro_cuenta(+) = a.nro_cuenta
;

