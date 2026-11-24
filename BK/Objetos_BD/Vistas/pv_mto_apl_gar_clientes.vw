CREATE OR REPLACE FORCE VIEW IT.PV_MTO_APL_GAR_CLIENTES AS
SELECT 2 orden,
       a.cod_persona,
       a.nro_cuenta,
       a.nro_garantia,
       a.cod_garantia,
       a.mto_riesgo,
       b.cod_moneda moneda,
       b.cod_modulo,
       a.rowid fila
  FROM ov_cta_garantias a, ov_cta_vencidas b
 WHERE a.nro_cuenta = b.nro_cuenta
   AND a.mto_riesgo > 0
   AND a.cod_garantia != 2

UNION ALL
-- Prestamos. --JIRA 1234
SELECT 3 orden,
       a.cod_persona,
       a.nro_cuenta,
       a.nro_garantia,
       a.cod_garantia,
       a.mto_riesgo,
       b.cod_moneda moneda,
       b.cod_modulo,
       a.rowid fila
  FROM pr_cta_garantias a, pr_cta_prestamos b
 WHERE a.nro_cuenta = b.nro_cuenta
   AND a.mto_riesgo > 0
   AND a.cod_garantia != 2
   AND not exists (select 1
                          from ge_par_dinamicos g
                         where g.parametro in ('PRE_MAD_CONSTRUCCIONES','MAD_HIPOTECARIOS')
                           and g.cod_modulo = b.cod_modulo
                           and g.cod_modalidad = b.cod_modalidad
                           and g.val_parametro = 'S')    
UNION ALL
-- Cuentas Corrientes.
SELECT 5 orden,
       a.cod_persona,
       a.nro_cuenta,
       a.nro_garantia,
       a.cod_garantia,
       a.mto_riesgo,
       b.cod_moneda moneda,
       b.cod_modulo,
       a.rowid fila
  FROM cc_cta_garantias a, cc_cta_corrientes b
 WHERE a.nro_cuenta = b.nro_cuenta
   AND a.mto_riesgo > 0
   AND a.cod_garantia != 2

UNION ALL
-- Tarjetas.
SELECT 6 orden,
       a.cod_persona,
       a.nro_cuenta,
       a.nro_garantia,
       a.cod_garantia,
       a.mto_riesgo,
       b.cod_moneda moneda,
       b.cod_modulo,
       a.rowid fila
  FROM ta_cta_garantias a, ta_cta_tarjetas b
 WHERE a.nro_cuenta = b.nro_cuenta
   AND a.mto_riesgo > 0
   AND a.cod_garantia != 2

UNION ALL
-- Comercio Exterior.
SELECT 4 orden,
       a.cod_persona,
       a.nro_cuenta,
       a.nro_garantia,
       a.cod_garantia,
       a.mto_riesgo,
       b.cod_moneda moneda,
       b.cod_modulo,
       a.rowid fila
  FROM cx_cta_garantias a, cx_cta_importaciones b
 WHERE a.nro_cuenta = b.nro_cuenta
   AND a.mto_riesgo > 0
   AND a.cod_garantia != 2
;
