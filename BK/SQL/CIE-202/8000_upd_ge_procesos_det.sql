BEGIN pre_ini_aplicacion; pae_cnf.G_COD_MODULO := 1; END; 
/
update ge_procesos_det d
set d.nro_orden = 401
where d.cod_proceso=11
and d.nro_orden = 402;

update ge_procesos_det d
set d.nro_orden = 402
where d.cod_proceso=11
and d.nro_orden = 374;

commit;
