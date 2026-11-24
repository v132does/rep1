begin pre_ini_aplicacion;pae_cnf.g_cod_modulo := '1'; end;  
/
update it.ge_procesos_det d 
   set d.cod_programa = 'PRE_EJE_DEPURACION'
where d.cod_proceso=12 and d.nro_orden=23 and d.cod_programa='PRE_TAB_DEPURACION';

commit;
