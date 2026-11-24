BEGIN pre_ini_aplicacion; pae_cnf.G_COD_MODULO := 1; END;    
/
update ge_procesos_det d
set d.nro_orden = 104,
    d.cod_proceso = 10
where d.cod_proceso = 12
  and d.nro_orden = 29
  and d.cod_programa = 'PAS_TRA.PR_GEN_TRANSFERENCIAS';
commit;


