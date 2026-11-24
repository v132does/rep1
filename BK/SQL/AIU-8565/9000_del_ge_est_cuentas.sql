begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
delete ge_est_cuentas where cod_modalidad = 34 and cod_modulo = 3;

commit;
