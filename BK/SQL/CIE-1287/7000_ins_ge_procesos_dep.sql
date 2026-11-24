BEGIN pre_ini_aplicacion; pae_cnf.G_COD_MODULO := 1; END; 
/
insert into ge_procesos_dep (COD_PROCESO, COD_PROGRAMA, COD_PROCESO_PRE, COD_PROGRAMA_PRE, TIPO, OBSERVACION)
values (11, 'PRG_VER_CONSISTENCIA', 11, 'PRG_GEN_SAL_DIARIOS', 'P', 'El proceso PRG_VER_CONSISTENCIA debe lanzarse al finalizar el PRG_GEN_SAL_DIARIOS.');

insert into ge_procesos_dep (COD_PROCESO, COD_PROGRAMA, COD_PROCESO_PRE, COD_PROGRAMA_PRE, TIPO, OBSERVACION)
values (11, 'PRG_VER_JOB_CIERRE(11)', 11, 'PRG_VER_CONSISTENCIA', 'F', 'El proceso PRG_VER_JOB_CIERRE(11) no debe de iniciar sin que finalice el PRG_VER_CONSISTENCIA');

commit;

