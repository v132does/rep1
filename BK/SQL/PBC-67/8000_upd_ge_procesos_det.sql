Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
update ge_procesos_det
set obligatorio = 'N' 
where cod_proceso = 11
and   nro_orden = 348;
/
commit;