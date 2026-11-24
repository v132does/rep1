BEGIN pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
DELETE FROM ba_cod_referencias b
WHERE dominio = 'INH_CAU_ROLES';

COMMIT;
