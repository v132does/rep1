CREATE OR REPLACE VIEW IT.PV_MTO_APL_GAR_CERRADAS AS
SELECT gc.cod_modulo,
       gc.cod_moneda,
       gc.nro_cuenta,
       pr.mto_riesgo,
       pr.mto_aplicado,
       pr.rowid fila,
       pr.cod_garantia,
       pr.nro_garantia
  FROM pr_cta_garantias pr, pr_cta_prestamos gc
 WHERE pr.nro_cuenta = gc.nro_cuenta
   AND pr.nro_garantia > 2
 UNION ALL
      --Tarjetas
 SELECT gc.cod_modulo,
        gc.cod_moneda,
        gc.nro_cuenta,
        ta.mto_riesgo,
        ta.mto_aplicado,
        ta.rowid fila,
        ta.cod_garantia,
        ta.nro_garantia
   FROM ta_cta_garantias ta, ta_cta_tarjetas gc
  WHERE ta.nro_cuenta = gc.nro_cuenta
    AND ta.nro_garantia > 2

  UNION ALL
      --Cuenta Corriente
 SELECT gc.cod_modulo,
        gc.cod_moneda,
        gc.nro_cuenta,
        cc.mto_riesgo,
        cc.mto_aplicado,
        cc.rowid fila,
        cc.cod_garantia,
        cc.nro_garantia
  FROM cc_cta_garantias cc, cc_cta_corrientes gc
 WHERE cc.nro_cuenta = gc.nro_cuenta
   AND cc.nro_garantia > 2
 UNION ALL
      --Operaciones Vencidas
SELECT gc.cod_modulo,
       gc.cod_moneda,
       gc.nro_cuenta,
       ov.mto_riesgo,
       ov.mto_aplicado,
       ov.rowid fila,
       ov.cod_garantia,
       ov.nro_garantia
  FROM ov_cta_garantias ov, ov_cta_vencidas gc
 WHERE ov.nro_cuenta = gc.nro_cuenta
   AND ov.nro_garantia > 2
 UNION ALL
      --Comex
SELECT gc.cod_modulo,
       gc.cod_moneda,
       gc.nro_cuenta,
       cx.mto_riesgo,
       cx.mto_aplicado,
       cx.rowid fila,
       cx.cod_garantia,
       cx.nro_garantia
  FROM cx_cta_garantias cx, cx_cta_importaciones gc
 WHERE cx.nro_cuenta = gc.nro_cuenta
   AND cx.nro_garantia > 2;
