BEGIN pre_ini_aplicacion; pae_cnf.G_COD_MODULO := 1; END; 
/
update ge_procesos_det d
set d.nro_orden = 393,
    d.cod_proceso = 11
where d.cod_proceso = 12
  and d.nro_orden = 2
  and d.cod_programa = 'PRG_VER_CONSISTENCIA';
commit;
