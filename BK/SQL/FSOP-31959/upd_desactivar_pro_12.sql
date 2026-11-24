Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
update ge_procesos_det a 
set a.activo = 'N'
where a.cod_proceso = 12
and a.nro_orden = 20; -- REGISTRO DE DIAS MORA P. IMPAGOS

update ge_procesos_det a 
set a.activo = 'N'
where a.cod_proceso = 12
and a.nro_orden = 22; -- RENOVACION DE SOBREGIROS

update ge_procesos_det a 
set a.activo = 'N'
where a.cod_proceso = 12
and a.nro_orden = 160; -- GENERACION DE TELEGRAMAS

update ge_procesos_det a 
set a.activo = 'N'
where a.cod_proceso = 12
and a.nro_orden = 300; -- CONTROL DE PRESTAMOS P LINEA DE TC.

update ge_procesos_det a 
set a.activo = 'N'
where a.cod_proceso = 12
and a.nro_orden = 978; -- CAMBIO DE GESTORES

update ge_procesos_det a 
set a.activo = 'N'
where a.cod_proceso = 12
and a.nro_orden = 980; -- ACTUALIZA OFIICINAS

commit;
