BEGIN pre_ini_aplicacion; pae_cnf.G_COD_MODULO := 1; END;    
/
delete ge_procesos_det d where d.cod_proceso = 12 and nro_orden = 4;
commit;
