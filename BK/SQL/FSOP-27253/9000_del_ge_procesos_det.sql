BEGIN pre_ini_aplicacion; pae_cnf.G_COD_MODULO := 1; END; 
/
delete ge_procesos_det p where p.cod_proceso=10 and p.nro_orden = 250;

commit;

