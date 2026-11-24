SET DEFINE OFF;

BEGIN  
  PRE_INI_APLICACION;  
  PAE_CNF.G_COD_MODULO := 1;  
END;
/

-- =====================================================================================
-- NOR-556 | Modificación del valor formato en ge_procesos_det
-- Objetivo : el formato del archivo generado cambia de txt a csv
-- =====================================================================================

-- Verificación previa
SELECT formato
  FROM it.ge_procesos_det
 WHERE cod_proceso = '992'
   AND nro_orden   = '6';
 
 UPDATE it.ge_procesos_det
    SET formato     = 'TXT'
  WHERE cod_proceso = '992'
    AND nro_orden   = '6';
 
COMMIT;

-- Verificación posterior
SELECT formato
  FROM it.ge_procesos_det
 WHERE cod_proceso = '992'
   AND nro_orden   = '6';
/

PROMPT === SCRIPT 7000_upd_ge_procesos_det.sql COMPLETADO OK ===
 