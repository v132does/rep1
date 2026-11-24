BEGIN pre_ini_aplicacion; pae_cnf.G_COD_MODULO := 1; END; 
/
delete ge_procesos_dep
where cod_programa = 'PAS_TRA.PR_GEN_TRANSFERENCIAS' 
   or cod_programa_pre = 'PAS_TRA.PR_GEN_TRANSFERENCIAS';
commit;
