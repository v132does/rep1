begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
update ge_procesos_det t
set t.activo='N'
where t.cod_proceso=11
and t.nro_orden=364;

commit;