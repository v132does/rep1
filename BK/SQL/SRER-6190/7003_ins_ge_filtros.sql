-- ============================================================
-- Script: findia_GE_FILTROS_ANEXO.sql
-- Objetivo: INSERT de filtro ANEXO en FINDIA
-- Tabla:    GE_FILTROS
-- ============================================================

BEGIN
  PRE_INI_APLICACION;
  PAE_CNF.G_COD_MODULO := 1;
  COMMIT;
END;
/

SET DEFINE OFF;

INSERT INTO ge_filtros
(
    cod_campo,
    descripcion,
    tip_campo,
    lon_campo,
    tip_dato,
    val_max_permitido,
    val_min_permitido,
    nom_tab_asociada,
    nom_referencia,
    nro_orden,
    det_sql,
    usu_insercion,
    fec_insercion,
    usu_modificacion,
    fec_modificacion,
    observacion,
    tipo,
    afe_segmentacion,
    afe_puntuacion,
    afe_reportes,
    afe_consultas,
    afe_reclamos,
    tip_sol_igual,
    permiso
)
SELECT
    'ANEXO',
    'Anexo a descargar',
    'N',
    2,
    'V',
    NULL,
    NULL,
    NULL,
    'ANEXO',
    NULL,
    -- Lista fija de 11 programas BCP (configuración inicial SRER-6036).
    -- Si se incorporan nuevos informes BCP, insertar el registro correspondiente en ba_par_reportes
    -- y actualizar este filtro con un INSERT separado en un nuevo script.
    'SELECT descripcion , TO_CHAR( ROW_NUMBER() OVER (ORDER BY descripcion ASC)) num from ba_programas where cod_programa IN (''BLANPLSO'', ''BLBANEXT'', ''BLBANPAI'', ''BLRESGAR'', ''BLCASHCO'', ''BLHIPOTE'', ''BLPRENDA'', ''BLFOGAPY'', ''BLFOGAMU'', ''BLFOGAVI'', ''BLBONSUB'') UNION SELECT ''TODOS'', ''0'' from dual',
    'IT',
    SYSDATE,
    'IT',
    SYSDATE,
    NULL,
    'G',
    'N',
    'N',
    'N',
    'N',
    'N',
    'N',
    NULL
FROM DUAL
WHERE NOT EXISTS (
    SELECT 1
    FROM ge_filtros
    WHERE cod_campo = 'ANEXO'
);

COMMIT;

SET DEFINE ON;
