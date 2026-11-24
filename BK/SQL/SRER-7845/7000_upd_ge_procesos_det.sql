begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end;
/
update ge_procesos_det
   set frecuencia = 'D'
 where cod_proceso = 931;

commit;
