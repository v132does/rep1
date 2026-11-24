begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end;
/
update ge_procesos_det a
set a.activo = 'N'
where a.cod_proceso = 10
and   a.nro_orden = '421';
commit;
