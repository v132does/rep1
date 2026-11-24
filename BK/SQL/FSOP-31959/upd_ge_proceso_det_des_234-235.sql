Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
update ge_procesos_det a
set a.activo = 'N'
where a.cod_proceso = 11 and a.nro_orden = 234;

update ge_procesos_det a
set a.activo = 'N'
where a.cod_proceso = 11 and a.nro_orden = 235;
commit;
select * from ge_procesos_det a where a.cod_proceso = 11 and a.nro_orden in (234,235);
