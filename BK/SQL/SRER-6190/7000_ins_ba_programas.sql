-- ============================================================
-- Script: findia_BA_PROGRAMAS_nuevos_reportes.sql
-- Objetivo: INSERT de 10 nuevos programas en FINDIA
-- Tabla:    BA_PROGRAMAS
-- ============================================================

BEGIN
  PRE_INI_APLICACION;
  PAE_CNF.G_COD_MODULO := 1;
  COMMIT;
END;
/

-- 1. Bancos Exterior
INSERT INTO ba_programas
(cod_programa, descripcion, cod_tip_programa, cod_modulo, ubi_ejecutable, ubi_fisico, des_detallada, cod_herramienta, observacion, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion, ope_mod_cerrado, cod_pro_equivalente, documento, ubi_menu, ina_cierre)
SELECT
    'BLBANEXT',
    'Bancos Exterior',
    '3',
    '2',
    'Z:\GF10G\EXE',
    'Z:\GF10G\RDF',
    'Informe de Bancos Exterior para el BCP.',
    NULL,
    NULL,
    'IT',
    SYSDATE,
    'IT',
    SYSDATE,
    'N',
    NULL,
    EMPTY_BLOB(),
    'Informes => Contabilidad => Informe BCP',
    NULL
FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM ba_programas WHERE cod_programa = 'BLBANEXT');

-- 2. Bancos País
INSERT INTO ba_programas
(cod_programa, descripcion, cod_tip_programa, cod_modulo, ubi_ejecutable, ubi_fisico, des_detallada, cod_herramienta, observacion, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion, ope_mod_cerrado, cod_pro_equivalente, documento, ubi_menu, ina_cierre)
SELECT
    'BLBANPAI',
    'Bancos País',
    '3',
    '2',
    'Z:\GF10G\EXE',
    'Z:\GF10G\RDF',
    'Informe de Bancos País para el BCP.',
    NULL,
    NULL,
    'IT',
    SYSDATE,
    'IT',
    SYSDATE,
    'N',
    NULL,
    EMPTY_BLOB(),
    'Informes => Contabilidad => Informe BCP',
    NULL
FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM ba_programas WHERE cod_programa = 'BLBANPAI');

-- 3. Resumen Garantías
INSERT INTO ba_programas
(cod_programa, descripcion, cod_tip_programa, cod_modulo, ubi_ejecutable, ubi_fisico, des_detallada, cod_herramienta, observacion, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion, ope_mod_cerrado, cod_pro_equivalente, documento, ubi_menu, ina_cierre)
SELECT
    'BLRESGAR',
    'Resumen Garantías',
    '3',
    '2',
    'Z:\GF10G\EXE',
    'Z:\GF10G\RDF',
    'Informe Resumen de Garantías para el BCP.',
    NULL,
    NULL,
    'IT',
    SYSDATE,
    'IT',
    SYSDATE,
    'N',
    NULL,
    EMPTY_BLOB(),
    'Informes => Contabilidad => Informe BCP',
    NULL
FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM ba_programas WHERE cod_programa = 'BLRESGAR');

-- 4. Cash Colateral
INSERT INTO ba_programas
(cod_programa, descripcion, cod_tip_programa, cod_modulo, ubi_ejecutable, ubi_fisico, des_detallada, cod_herramienta, observacion, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion, ope_mod_cerrado, cod_pro_equivalente, documento, ubi_menu, ina_cierre)
SELECT
    'BLCASHCO',
    'Cash Colateral',
    '3',
    '2',
    'Z:\GF10G\EXE',
    'Z:\GF10G\RDF',
    'Informe de Cash Colateral para el BCP.',
    NULL,
    NULL,
    'IT',
    SYSDATE,
    'IT',
    SYSDATE,
    'N',
    NULL,
    EMPTY_BLOB(),
    'Informes => Contabilidad => Informe BCP',
    NULL
FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM ba_programas WHERE cod_programa = 'BLCASHCO');

-- 5. Hipotecas
INSERT INTO ba_programas
(cod_programa, descripcion, cod_tip_programa, cod_modulo, ubi_ejecutable, ubi_fisico, des_detallada, cod_herramienta, observacion, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion, ope_mod_cerrado, cod_pro_equivalente, documento, ubi_menu, ina_cierre)
SELECT
    'BLHIPOTE',
    'Inf. Hipotecas',
    '3',
    '2',
    'Z:\GF10G\EXE',
    'Z:\GF10G\RDF',
    'Informe de Hipotecas para el BCP.',
    NULL,
    NULL,
    'IT',
    SYSDATE,
    'IT',
    SYSDATE,
    'N',
    NULL,
    EMPTY_BLOB(),
    'Informes => Contabilidad => Informe BCP',
    NULL
FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM ba_programas WHERE cod_programa = 'BLHIPOTE');

-- 6. Prendas
INSERT INTO ba_programas
(cod_programa, descripcion, cod_tip_programa, cod_modulo, ubi_ejecutable, ubi_fisico, des_detallada, cod_herramienta, observacion, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion, ope_mod_cerrado, cod_pro_equivalente, documento, ubi_menu, ina_cierre)
SELECT
    'BLPRENDA',
    'Inf. Prendas',
    '3',
    '2',
    'Z:\GF10G\EXE',
    'Z:\GF10G\RDF',
    'Informe de Prendas para el BCP.',
    NULL,
    NULL,
    'IT',
    SYSDATE,
    'IT',
    SYSDATE,
    'N',
    NULL,
    EMPTY_BLOB(),
    'Informes => Contabilidad => Informe BCP',
    NULL
FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM ba_programas WHERE cod_programa = 'BLPRENDA');

-- 7. FOGAPY
INSERT INTO ba_programas
(cod_programa, descripcion, cod_tip_programa, cod_modulo, ubi_ejecutable, ubi_fisico, des_detallada, cod_herramienta, observacion, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion, ope_mod_cerrado, cod_pro_equivalente, documento, ubi_menu, ina_cierre)
SELECT
    'BLFOGAPY',
    'Inf. FOGAPY',
    '3',
    '2',
    'Z:\GF10G\EXE',
    'Z:\GF10G\RDF',
    'Informe de FOGAPY para el BCP.',
    NULL,
    NULL,
    'IT',
    SYSDATE,
    'IT',
    SYSDATE,
    'N',
    NULL,
    EMPTY_BLOB(),
    'Informes => Contabilidad => Informe BCP',
    NULL
FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM ba_programas WHERE cod_programa = 'BLFOGAPY');

-- 8. FOGAMU
INSERT INTO ba_programas
(cod_programa, descripcion, cod_tip_programa, cod_modulo, ubi_ejecutable, ubi_fisico, des_detallada, cod_herramienta, observacion, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion, ope_mod_cerrado, cod_pro_equivalente, documento, ubi_menu, ina_cierre)
SELECT
    'BLFOGAMU',
    'Inf. FOGAMU',
    '3',
    '2',
    'Z:\GF10G\EXE',
    'Z:\GF10G\RDF',
    'Informe de FOGAMU para el BCP.',
    NULL,
    NULL,
    'IT',
    SYSDATE,
    'IT',
    SYSDATE,
    'N',
    NULL,
    EMPTY_BLOB(),
    'Informes => Contabilidad => Informe BCP',
    NULL
FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM ba_programas WHERE cod_programa = 'BLFOGAMU');

-- 9. FOGAVI
INSERT INTO ba_programas
(cod_programa, descripcion, cod_tip_programa, cod_modulo, ubi_ejecutable, ubi_fisico, des_detallada, cod_herramienta, observacion, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion, ope_mod_cerrado, cod_pro_equivalente, documento, ubi_menu, ina_cierre)
SELECT
    'BLFOGAVI',
    'Inf. FOGAVI',
    '3',
    '2',
    'Z:\GF10G\EXE',
    'Z:\GF10G\RDF',
    'Informe de FOGAVI para el BCP.',
    NULL,
    NULL,
    'IT',
    SYSDATE,
    'IT',
    SYSDATE,
    'N',
    NULL,
    EMPTY_BLOB(),
    'Informes => Contabilidad => Informe BCP',
    NULL
FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM ba_programas WHERE cod_programa = 'BLFOGAVI');

-- 10. Bonos Subordinados
INSERT INTO ba_programas
(cod_programa, descripcion, cod_tip_programa, cod_modulo, ubi_ejecutable, ubi_fisico, des_detallada, cod_herramienta, observacion, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion, ope_mod_cerrado, cod_pro_equivalente, documento, ubi_menu, ina_cierre)
SELECT
    'BLBONSUB',
    'Bonos Subordinados',
    '3',
    '2',
    'Z:\GF10G\EXE',
    'Z:\GF10G\RDF',
    'Informe de Bonos Subordinados para el BCP.',
    NULL,
    NULL,
    'IT',
    SYSDATE,
    'IT',
    SYSDATE,
    'N',
    NULL,
    EMPTY_BLOB(),
    'Informes => Contabilidad => Informe BCP',
    NULL
FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM ba_programas WHERE cod_programa = 'BLBONSUB');

COMMIT;
