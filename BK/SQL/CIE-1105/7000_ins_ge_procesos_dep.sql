BEGIN pre_ini_aplicacion; pae_cnf.G_COD_MODULO := 1; END; 
/
insert into ge_procesos_dep (COD_PROCESO, COD_PROGRAMA, COD_PROCESO_PRE, COD_PROGRAMA_PRE, TIPO, OBSERVACION)
values (10, 'PAS_TRA.PR_GEN_TRANSFERENCIAS', 10, 'PRB_CON_TRA_HIS', 'P', 'El proceso PAS_TRA.PR_GEN_TRANSFERENCIAS debe lanzarse al finalizar el PRB_CON_TRA_HIS.');

insert into ge_procesos_dep (COD_PROCESO, COD_PROGRAMA, COD_PROCESO_PRE, COD_PROGRAMA_PRE, TIPO, OBSERVACION)
values (10, 'PAG_EXT.PR_GEN_EXT_MENSUAL', 10, 'PAS_TRA.PR_GEN_TRANSFERENCIAS', 'F', 'El proceso PAG_EXT.PR_GEN_EXT_MENSUAL no debe de iniciar sin que finalice el PAS_TRA.PR_GEN_TRANSFERENCIAS');

commit;
