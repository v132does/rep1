BEGIN pre_ini_aplicacion; pae_cnf.G_COD_MODULO := 1; END; 
/
update ge_procesos_det d 
set d.cod_proceso = 10,
    d.nro_orden = 424
where d.cod_proceso = 12 
  and d.cod_programa = 'PRP_GEN_INV_GARANTIAS';
commit;
