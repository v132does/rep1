begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end;
/
update ge_procesos_det d
set d.activo = 'S'
where d.cod_proceso = '11'
and d.nro_orden = '108';

update ge_procesos_det d
set d.activo = 'S'
where d.cod_proceso = '11'
and d.nro_orden = '109';

update ge_procesos_det d
set d.activo = 'S'
where d.cod_proceso = '11'
and d.nro_orden = '110';

update ge_procesos_det d
set d.activo = 'S'
where d.cod_proceso = '11'
and d.nro_orden = '231';

update ge_procesos_det d
set d.activo = 'S'
where d.cod_proceso = '10'
and d.nro_orden = '150';


delete from ge_procesos_det d
where d.cod_proceso = '10'
and d.nro_orden = '365';

update ge_procesos_det d
set d.activo = 'S'
where d.cod_proceso = '10'
and d.nro_orden = '366';

commit;
