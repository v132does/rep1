CREATE OR REPLACE FORCE VIEW IT.PV_CTA_OPERACIONES AS
SELECT ge.cod_moneda, a.nro_cuenta, ge.cod_modulo, a.mto_apl_computable,a.mto_riesgo
  FROM pr_cta_garantias a, ge_cuentas ge, pr_gar_tipos pr
 WHERE a.mto_apl_computable > 0
   AND a.nro_cuenta = ge.nro_cuenta
   AND a.cod_garantia = pr.cod_garantia
   AND nvl(pr.computable, 'N') = 'S'
UNION ALL
SELECT ge.cod_moneda, a.nro_cuenta, ge.cod_modulo, a.mto_apl_computable,a.mto_riesgo
  FROM cc_cta_garantias a, ge_cuentas ge, pr_gar_tipos pr
 WHERE a.mto_apl_computable > 0
   AND a.nro_cuenta = ge.nro_cuenta
   AND a.cod_garantia = pr.cod_garantia
   AND nvl(pr.computable, 'N') = 'S'
UNION ALL
SELECT ge.cod_moneda, a.nro_cuenta, ge.cod_modulo, a.mto_apl_computable,a.mto_riesgo
 FROM ta_cta_garantias a, ge_cuentas ge, pr_gar_tipos pr
 WHERE a.mto_apl_computable > 0
   AND a.nro_cuenta = ge.nro_cuenta
   AND a.cod_garantia = pr.cod_garantia
   AND nvl(pr.computable, 'N') = 'S'
UNION ALL
SELECT ge.cod_moneda, a.nro_cuenta, ge.cod_modulo, a.mto_apl_computable,a.mto_riesgo
  FROM ov_cta_garantias a, ge_cuentas ge, pr_gar_tipos pr
 WHERE a.mto_apl_computable > 0
   AND a.nro_cuenta = ge.nro_cuenta
   AND a.cod_garantia = pr.cod_garantia
   AND nvl(pr.computable, 'N') = 'S'
UNION ALL
SELECT ge.cod_moneda, a.nro_cuenta, ge.cod_modulo, a.mto_apl_computable,a.mto_riesgo
  FROM cx_cta_garantias a, ge_cuentas ge, pr_gar_tipos pr
 WHERE a.mto_apl_computable > 0
   AND a.nro_cuenta = ge.nro_cuenta
   AND a.cod_garantia = pr.cod_garantia
   AND nvl(pr.computable, 'N') = 'S'
 order by 1;

