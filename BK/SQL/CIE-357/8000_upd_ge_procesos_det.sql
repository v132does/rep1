begin pre_ini_aplicacion;pae_cnf.g_cod_modulo := '1'; end;  
/
update ge_procesos_det w 
  set w.nro_orden=10
where w.cod_proceso=7 and w.nro_orden=5 and w.cod_programa='PAB_IVA.PR_PRO_CIERRE';      
commit;
