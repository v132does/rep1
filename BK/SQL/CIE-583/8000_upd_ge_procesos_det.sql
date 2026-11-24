BEGIN pre_ini_aplicacion; pae_cnf.G_COD_MODULO := 1; END;       
/
update ge_procesos_det d
set d.cod_proceso = 152,
   d.nro_orden = 1
where cod_proceso = 10
 and nro_orden = 334;
commit;

