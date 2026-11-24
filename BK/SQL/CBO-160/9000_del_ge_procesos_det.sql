begin pre_ini_aplicacion;pae_cnf.g_cod_modulo := '1'; end;  
/
delete it.ge_procesos_det w 
where w.cod_proceso= 11 and w.nro_orden= 7;

delete it.ge_procesos_det w 
where w.cod_proceso= 11 and w.nro_orden= 146;

commit;