BEGIN pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
delete ba_cod_referencias where dominio = 'TIP_FOR_RECHAZADO';

COMMIT;
