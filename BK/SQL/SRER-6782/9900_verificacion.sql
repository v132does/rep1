------------------------------
-- verificacion SRER-6782 --
------------------------------
-- Valida inserts/updates de:
--   01-Crea_modalidad_155.sql
--   2000_upd_ge_par_dinamicos.sql
--   7000_ins_ge_tas_fechas.sql
--   7001_ins_ba_cod_referencias.sql
------------------------------

SET SERVEROUTPUT ON SIZE UNLIMITED

PROMPT === 1) ge_modalidades (modalidad 155) ===
SELECT cod_modulo,
       cod_modalidad,
       descripcion,
       CASE
         WHEN cod_modulo = 10
          AND cod_modalidad = 155
          AND descripcion = 'PRESTAMOS REC. AFD + OTROS IVA 10%'
         THEN 'OK'
         ELSE 'ERROR'
       END AS resultado
  FROM ge_modalidades
 WHERE cod_modulo = 10
   AND cod_modalidad = 155;

PROMPT === 2) ge_tas_fechas (tasa 343 / modalidad 155) ===
SELECT cod_tasa,
       fec_vigencia,
       cod_modulo,
       cod_modalidad,
       val_base,
       val_tasa,
       aplicar,
       CASE
         WHEN cod_tasa = 343
          AND TRUNC(fec_vigencia) = TO_DATE('01/01/2026', 'DD/MM/YYYY')
          AND cod_modulo = 10
          AND cod_modalidad = 155
          AND NVL(val_base, 0) = 0
          AND val_tasa = 10
          AND aplicar = 'IN'
         THEN 'OK'
         ELSE 'ERROR'
       END AS resultado
  FROM ge_tas_fechas
 WHERE cod_tasa = 343
   AND cod_modulo = 10
   AND cod_modalidad = 155
   AND TRUNC(fec_vigencia) = TO_DATE('01/01/2026', 'DD/MM/YYYY');

PROMPT === 3) ba_cod_referencias (MES_PRO_MODALIDAD / 155) ===
SELECT dominio,
       significado,
       val_minimo,
       val_maximo,
       abreviatura,
       activo,
       CASE
         WHEN dominio = 'MES_PRO_MODALIDAD'
          AND significado = 'PRESTAMOS REC. AFD IVA 10%'
          AND val_minimo = '155'
          AND val_maximo = '50000000'
          AND abreviatura = 'MMCTAPRE'
          AND activo = 'S'
         THEN 'OK'
         ELSE 'ERROR'
       END AS resultado
  FROM ba_cod_referencias
 WHERE dominio = 'MES_PRO_MODALIDAD'
   AND val_minimo = '155';

PROMPT === 4) ge_par_dinamicos (SIG_NROCTA 150 / 155) ===
SELECT cod_modulo,
       cod_modalidad,
       parametro,
       val_parametro,
       CASE
         WHEN cod_modalidad = 155 AND val_parametro = '15500001' THEN 'OK'
         WHEN cod_modalidad = 150 AND val_parametro = '15000001' THEN 'OK'
         ELSE 'ERROR'
       END AS resultado
  FROM ge_par_dinamicos
 WHERE parametro = 'SIG_NROCTA'
   AND cod_modulo = 10
   AND cod_modalidad IN (150, 155)
 ORDER BY cod_modalidad;

PROMPT === 5) Resumen OK / ERROR / FALTANTE ===
SELECT check_id,
       descripcion,
       esperado,
       encontrado,
       CASE
         WHEN encontrado = esperado THEN 'OK'
         WHEN encontrado = 0 THEN 'FALTANTE'
         ELSE 'ERROR'
       END AS resultado
  FROM (
        SELECT 1 AS check_id,
               'ge_modalidades modalidad 155' AS descripcion,
               1 AS esperado,
               (SELECT COUNT(*)
                  FROM ge_modalidades
                 WHERE cod_modulo = 10
                   AND cod_modalidad = 155
                   AND descripcion = 'PRESTAMOS REC. AFD + OTROS IVA 10%') AS encontrado
          FROM dual
        UNION ALL
        SELECT 2,
               'ge_tas_fechas tasa 343 modalidad 155',
               1,
               (SELECT COUNT(*)
                  FROM ge_tas_fechas
                 WHERE cod_tasa = 343
                   AND cod_modulo = 10
                   AND cod_modalidad = 155
                   AND TRUNC(fec_vigencia) = TO_DATE('01/01/2026', 'DD/MM/YYYY')
                   AND NVL(val_base, 0) = 0
                   AND val_tasa = 10
                   AND aplicar = 'IN')
          FROM dual
        UNION ALL
        SELECT 3,
               'ba_cod_referencias MES_PRO_MODALIDAD 155',
               1,
               (SELECT COUNT(*)
                  FROM ba_cod_referencias
                 WHERE dominio = 'MES_PRO_MODALIDAD'
                   AND val_minimo = '155'
                   AND significado = 'PRESTAMOS REC. AFD IVA 10%'
                   AND val_maximo = '50000000'
                   AND abreviatura = 'MMCTAPRE'
                   AND activo = 'S')
          FROM dual
        UNION ALL
        SELECT 4,
               'ge_par_dinamicos SIG_NROCTA modalidad 155',
               1,
               (SELECT COUNT(*)
                  FROM ge_par_dinamicos
                 WHERE parametro = 'SIG_NROCTA'
                   AND cod_modulo = 10
                   AND cod_modalidad = 155
                   AND val_parametro = '15500001')
          FROM dual
        UNION ALL
        SELECT 5,
               'ge_par_dinamicos SIG_NROCTA modalidad 150',
               1,
               (SELECT COUNT(*)
                  FROM ge_par_dinamicos
                 WHERE parametro = 'SIG_NROCTA'
                   AND cod_modulo = 10
                   AND cod_modalidad = 150
                   AND val_parametro = '15000001')
          FROM dual
       )
 ORDER BY check_id;
