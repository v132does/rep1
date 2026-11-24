BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:= 1; END;
/
UPDATE ge_procesos_det
   SET frecuencia = 'D'    
 WHERE cod_proceso = 10
   AND nro_orden = 999;

COMMIT;
