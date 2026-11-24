Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/
delete from ge_procesos_det 
where cod_proceso = 12
  and nro_orden = 30
  and upper(cod_programa) = 'PRB_GEN_PRE_CIERRE';
 
COMMIT;
