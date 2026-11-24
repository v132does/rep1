begin pre_ini_aplicacion;pae_cnf.g_cod_modulo := '1'; end;  
/
update it.ge_procesos_det_his p
   set p.nro_secuencia = 1;

commit;