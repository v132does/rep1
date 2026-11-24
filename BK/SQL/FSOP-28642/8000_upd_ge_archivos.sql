BEGIN pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
UPDATE ge_archivos
SET    archivo = 'CENVRMT0046.TXT'
WHERE  referencia = 'CHE_ENV_PRODEP_REG';

UPDATE ge_arc_tablas
SET    archivo = 'CENVRMT0046.TXT'
WHERE  referencia = 'CHE_ENV_PRODEP_REG';

UPDATE ge_arc_campos
SET    archivo = 'CENVRMT0046.TXT'
WHERE  referencia = 'CHE_ENV_PRODEP_REG';

COMMIT;
