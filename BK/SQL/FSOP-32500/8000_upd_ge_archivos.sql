BEGIN pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
UPDATE ge_archivos w
   SET w.pos_proceso = NULL
 WHERE w.referencia IN ('CHE_RECHBC', 'CHE_RECHBC_USD');

COMMIT;
