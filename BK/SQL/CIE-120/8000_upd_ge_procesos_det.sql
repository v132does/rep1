BEGIN pre_ini_aplicacion; pae_cnf.G_COD_MODULO := 1; END; 
/
update ge_procesos_det d
set d.nro_orden = 390
where d.cod_proceso=11
and d.nro_orden = 399;

update ge_procesos_det d
set d.nro_orden = 391
where d.cod_proceso=11
and d.nro_orden = 401;

update ge_procesos_det d
set d.nro_orden = 394
where d.cod_proceso=11
and d.nro_orden = 384;

commit;

