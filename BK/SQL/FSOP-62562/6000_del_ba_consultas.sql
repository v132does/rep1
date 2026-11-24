Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
delete ba_par_consultas where cod_consulta = 'CD_SAL_PLO';

delete ba_consultas where cod_consulta = 'CD_SAL_PLO';

COMMIT;
