Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
UPDATE BA_CONSULTAS
SET    PERMISO = NULL
WHERE COD_CONSULTA = 'CD_SAL_PLO';

COMMIT;
