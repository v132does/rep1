CREATE OR REPLACE FORCE VIEW IT.PV_DEU_GAR_TERCEROS AS
SELECT 1 orden, --JIRA 1234
       b.cat_riesgo cat_riesgo,
       a.mto_riesgo mto_riesgo,
       a.nro_cuenta nro_cuenta,
       (CASE
          WHEN a.cod_garantia < 3 THEN
           NULL
          ELSE
           a.nro_garantia
       END) nro_garantia,
       fug_obt_mon_cta(a.nro_cuenta) cod_moneda,
       c.cod_modulo cod_modulo,
       (CASE
          WHEN a.cod_garantia < 3 THEN
           NULL
          ELSE
           a.cod_garantia
       END) cod_garantia,
       a.cod_persona,
       a.rowid fila
  FROM pr_cta_garantias a, ge_clientes b, ge_cta_clientes c, ge_cuentas g, ge_est_cuentas p
 WHERE a.cod_persona = b.cod_persona
   AND a.nro_cuenta = c.nro_cuenta
   and a.cod_persona = c.cod_persona
         -- nuevo--
   and c.nro_cuenta = g.nro_cuenta
   AND p.cod_modulo = g.cod_modulo
   AND p.cod_modalidad = g.cod_modalidad
   and p.estado = g.estado
   AND p.activo = 'S'
   AND g.estado <> 'I'

   AND (nvl((SELECT G.VAL_PARAMETRO
            FROM GE_PAR_DINAMICOS G
           WHERE PARAMETRO = 'MAD_HIPOTECARIOS'
             AND COD_MODULO = c.cod_modulo
             AND COD_MODALIDAD = c.cod_modalidad),'N')='S'
     OR nvl((SELECT G.VAL_PARAMETRO
           FROM GE_PAR_DINAMICOS G
          WHERE PARAMETRO = 'PRE_MAD_CONSTRUCCIONES'
            AND COD_MODULO = c.cod_modulo
            AND COD_MODALIDAD = c.cod_modalidad),'N')='S')

UNION
SELECT 3 orden, --JIRA 1234
       b.cat_riesgo cat_riesgo,
       a.mto_riesgo mto_riesgo,
       a.nro_cuenta nro_cuenta,
       (CASE
          WHEN a.cod_garantia < 3 THEN
           NULL
          ELSE
           a.nro_garantia
       END) nro_garantia,
       fug_obt_mon_cta(a.nro_cuenta) cod_moneda,
       c.cod_modulo cod_modulo,
       (CASE
          WHEN a.cod_garantia < 3 THEN
           NULL
          ELSE
           a.cod_garantia
       END) cod_garantia,
       a.cod_persona,
       a.rowid fila
  FROM pr_cta_garantias a, ge_clientes b, ge_cta_clientes c, ge_cuentas g, ge_est_cuentas p
 WHERE a.cod_persona = b.cod_persona
   AND a.nro_cuenta = c.nro_cuenta
      -- nuevo--
   and c.nro_cuenta = g.nro_cuenta
   AND p.cod_modulo = g.cod_modulo
   AND p.cod_modalidad = g.cod_modalidad
   and p.estado = g.estado
   AND p.activo = 'S'
   AND g.estado <> 'I'
   AND (nvl((SELECT G.VAL_PARAMETRO
           FROM GE_PAR_DINAMICOS G
          WHERE PARAMETRO = 'MAD_HIPOTECARIOS'
            AND COD_MODULO = c.cod_modulo
            AND COD_MODALIDAD = c.cod_modalidad),'N')='N'
    AND nvl((SELECT G.VAL_PARAMETRO
          FROM GE_PAR_DINAMICOS G
         WHERE PARAMETRO = 'PRE_MAD_CONSTRUCCIONES'
           AND COD_MODULO = c.cod_modulo
           AND COD_MODALIDAD = c.cod_modalidad),'N')='N')

UNION
--Cuenta Corriente.
SELECT 5 orden, --JIRA 1234
       b.cat_riesgo cat_riesgo,
       a.mto_riesgo mto_riesgo,
       a.nro_cuenta nro_cuenta,
       (CASE
          WHEN a.cod_garantia < 3 THEN
           NULL
          ELSE
           a.nro_garantia
       END) nro_garantia,
       fug_obt_mon_cta(a.nro_cuenta) cod_moneda,
       c.cod_modulo cod_modulo,
       (CASE
          WHEN a.cod_garantia < 3 THEN
           NULL
          ELSE
           a.cod_garantia
       END) cod_garantia,
       a.cod_persona,
       a.rowid fila
  FROM cc_cta_garantias a, ge_clientes b, ge_cta_clientes c
 WHERE a.cod_persona = b.cod_persona
   AND a.nro_cuenta = c.nro_cuenta
   and a.cod_persona = c.cod_persona

UNION
--Tarjetas.
SELECT 6 orden, --JIRA 1234
       b.cat_riesgo cat_riesgo,
       a.mto_riesgo mto_riesgo,
       a.nro_cuenta nro_cuenta,
       (CASE
          WHEN a.cod_garantia < 3 THEN
           NULL
          ELSE
           a.nro_garantia
       END) nro_garantia,
       fug_obt_mon_cta(a.nro_cuenta) cod_moneda,
       c.cod_modulo cod_modulo,
       (CASE
          WHEN a.cod_garantia < 3 THEN
           NULL
          ELSE
           a.cod_garantia
       END) cod_garantia,
       a.cod_persona,
       a.rowid fila
  FROM ta_cta_garantias a, ge_clientes b, ge_cta_clientes c
 WHERE a.cod_persona = b.cod_persona
   AND a.nro_cuenta = c.nro_cuenta
   and a.cod_persona = c.cod_persona

UNION
--Operaciones Vencidas.
SELECT 2 orden, --JIRA 1234
       b.cat_riesgo cat_riesgo,
       a.mto_riesgo mto_riesgo,
       a.nro_cuenta nro_cuenta,
       (CASE
          WHEN a.cod_garantia < 3 THEN
           NULL
          ELSE
           a.nro_garantia
       END) nro_garantia,
       fug_obt_mon_cta(a.nro_cuenta) cod_moneda,
       c.cod_modulo cod_modulo,
       (CASE
          WHEN a.cod_garantia < 3 THEN
           NULL
          ELSE
           a.cod_garantia
       END) cod_garantia,
       a.cod_persona,
       a.rowid fila
  FROM ov_cta_garantias a, ge_clientes b, ge_cta_clientes c
 WHERE a.cod_persona = b.cod_persona
   AND a.nro_cuenta = c.nro_cuenta
   and a.cod_persona = c.cod_persona

UNION
--Comercio Exterior.
SELECT 4 orden, --JIRA 1234
       b.cat_riesgo cat_riesgo,
       a.mto_riesgo mto_riesgo,
       a.nro_cuenta nro_cuenta,
       (CASE
          WHEN a.cod_garantia < 3 THEN
           NULL
          ELSE
           a.nro_garantia
       END) nro_garantia,
       fug_obt_mon_cta(a.nro_cuenta) cod_moneda,
       c.cod_modulo cod_modulo,
       (CASE
          WHEN a.cod_garantia < 3 THEN
           NULL
          ELSE
           a.cod_garantia
       END) cod_garantia,
       a.cod_persona,
       a.rowid fila
  FROM cx_cta_garantias a, ge_clientes b, ge_cta_clientes c
 WHERE a.cod_persona = b.cod_persona
   AND a.nro_cuenta = c.nro_cuenta
   and a.cod_persona = c.cod_persona
;

