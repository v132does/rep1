BEGIN pre_ini_aplicacion; pae_cnf.G_COD_MODULO := 1; END;  
/
update ge_procesos_det g
set g.activo = 'S'
where g.cod_proceso = 11
and g.nro_orden = 40;

commit;
