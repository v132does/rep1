begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; pae_cnf.G_PROGRAMA := 'GPPROFIN'; end; 
/
update ge_procesos_det
   set activo = 'S'
 where cod_proceso = 11
   and nro_orden = 994;--1 registro afectado
/
commit;
