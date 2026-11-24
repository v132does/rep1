CREATE OR REPLACE FORCE VIEW IT.GV_TAS_VAR_FIJAS AS
SELECT t.cod_tasa,
       fug_obt_des_tasa(t.cod_tasa) DESC_TASA,
       tra.cod_transaccion,
       tra.descripcion,
       t.cod_modulo,
       t.cod_modalidad,
       CASE WHEN (t.cod_modalidad IS NOT NULL) THEN
         FUG_OBT_DES_MODAL(t.cod_modulo, t.cod_modalidad)
       ELSE
         'GENERAL'
       END MODAL_DESC,
       t.cod_sub_modalidad,
       CASE WHEN (t.cod_sub_modalidad IS NOT NULL) THEN
         FUG_OBT_DES_MODAL(t.cod_modulo, t.cod_modalidad) 
       ELSE
         'GENERAL'
       END SUBMODAL_DESC,
       t.cod_moneda, 
       t.cod_oficina,
       t.tip_iva,
       t.fec_vigencia,
       t.val_minimo,
       t.val_maximo,
       t.val_tasa,
       NULL val_hasta
  FROM GE_TAS_FECHAS t, GE_TRANSACCIONES TRA
 WHERE t.cod_tasa = tra.cod_tasa(+) 
   AND t.cod_modulo = tra.cod_modulo(+)
   AND t.cod_modalidad = tra.cod_modalidad(+)
   AND t.nro_cuenta IS NULL AND t.cod_persona IS NULL
   And t.fec_vigencia in (SELECT MAX(t1.fec_vigencia)
                            FROM ge_tas_fechas t1
                           WHERE t1.cod_tasa= t.cod_tasa
                             AND NVL(t1.cod_oficina,1)= NVL(t.cod_oficina,1)
                             AND NVL(t1.cod_moneda,'X')= NVL(t.cod_moneda,'X')
                             AND NVL(t1.cod_modulo,1)= NVL(t.cod_modulo,1)
                             AND NVL(t1.cod_modalidad,1)= NVL(t.cod_modalidad,1)
                             AND NVL(t1.nro_cuenta,'X')= NVL(t.nro_cuenta,'X')
                             AND NVL(t1.tip_iva,'X')= NVL(t.tip_iva,'X')
                             AND NVL(t1.cod_persona,'X')= NVL(t.cod_persona,'X')
                             AND NVL(t1.cod_sub_modalidad,1)= NVL(t.cod_sub_modalidad,1))
UNION
--2- Tasas que existan en transacciones y no posean módulo y/ó modalidad igual a los cargados en tasas
SELECT t.cod_tasa,
       fug_obt_des_tasa(t.cod_tasa),
       t.cod_transaccion,
       t.descripcion,
       t.cod_modulo,
       t.cod_modalidad,
       CASE WHEN (t.cod_modalidad IS NOT NULL) THEN
         FUG_OBT_DES_MODAL(t.cod_modulo, t.cod_modalidad)
       ELSE
         'GENERAL'
       END,
       NULL,
       NULL,
       NULL,
       NULL,
       NULL,
       NULL,
       NULL,
       NULL,
       NULL,
       NULL
  FROM ge_transacciones t
 WHERE NOT EXISTS (SELECT *
                     FROM ge_tas_fechas a
                    WHERE a.COD_TASA = t.cod_tasa
                      AND a.cod_modulo = t.cod_modulo
                      AND a.cod_modalidad = t.cod_modalidad)
   AND t.cod_tasa IS NOT NULL
UNION
--3- Tasas variables y existen en transacciones
SELECT t.cod_tasa,
       fug_obt_des_tasa(t.cod_tasa),
       tra.cod_transaccion,
       tra.descripcion,
       t.cod_modulo,
       t.cod_modalidad,
       CASE WHEN (t.cod_modalidad IS NOT NULL) THEN
          FUG_OBT_DES_MODAL(t.cod_modulo, t.cod_modalidad)
       ELSE
          'GENERAL'
       END,
       t.cod_sub_modalidad,
       CASE WHEN (t.cod_sub_modalidad IS NOT NULL) THEN
          FUG_OBT_DES_MODAL(t.cod_modulo, t.cod_modalidad)
       ELSE
          'GENERAL'
       END,
       t.cod_moneda,
       t.cod_oficina,
       NULL,
       t.fec_vigencia,
       NULL,
       NULL,
       t.val_tasa,
       t.val_hasta
  FROM GE_TAS_RANGOS t, GE_TRANSACCIONES tra
 WHERE t.nro_cuenta IS NULL
   AND t.cod_tasa = tra.cod_tasa(+)
   AND t.cod_modulo = tra.cod_modulo(+)
   AND t.cod_modalidad = tra.cod_modalidad(+)
   And t.fec_vigencia IN
       (SELECT MAX(t1.fec_vigencia)
          FROM ge_tas_rangos t1
         WHERE t1.cod_tasa = t.cod_tasa
           AND NVL(t1.cod_oficina, 1) = NVL(t.cod_oficina, 1)
           AND NVL(t1.cod_moneda,'X') = NVL(t.cod_moneda,'X')
           AND NVL(t1.cod_modulo, 1) = NVL(t.cod_modulo, 1)
           AND NVL(t1.cod_modalidad, 1) = NVL(t.cod_modalidad, 1)
           AND NVL(t1.nro_cuenta, 'X') = NVL(t.nro_cuenta, 'X')
           AND NVL(t1.Val_Hasta, 1) = NVL(t.val_hasta, 1)
           AND NVL(t1.cod_sub_modalidad, 1) = NVL(t.cod_sub_modalidad, 1))
ORDER BY cod_tasa
;

