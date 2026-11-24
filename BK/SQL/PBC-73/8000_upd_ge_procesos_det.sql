BEGIN pre_ini_aplicacion; pae_cnf.G_COD_MODULO := 1; END; 
/
update ge_procesos_det g  
 set g.cod_proceso = 151,
     g.nro_orden = 1
where g.cod_proceso = 11 
  and g.nro_orden = 475;

commit;
