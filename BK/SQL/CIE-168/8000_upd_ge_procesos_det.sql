begin pre_ini_aplicacion;pae_cnf.g_cod_modulo := '1'; end;  
/
update ge_procesos_det w
  set w.activo='S'
where w.cod_proceso=11 and w.nro_orden=262
  and w.cod_programa = 'PRA_CAP_CTA_VISTA_CIERRE';

