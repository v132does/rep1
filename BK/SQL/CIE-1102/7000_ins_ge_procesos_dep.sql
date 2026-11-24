BEGIN pre_ini_aplicacion; pae_cnf.G_COD_MODULO := 1; END; 
/
insert into ge_procesos_dep (COD_PROCESO, COD_PROGRAMA, COD_PROCESO_PRE, COD_PROGRAMA_PRE, TIPO, OBSERVACION)
values (11, 'PAS_BCP.PR_GEN_ENC_ASCII', 11, 'PAB_RES.PR_GEN_INV_CTA_RES', 'P', 'El proceso PAS_BCP.PR_GEN_ENC_ASCII debe lanzarse al finalizar el PAB_RES.PR_GEN_INV_CTA_RES.');
insert into ge_procesos_dep (COD_PROCESO, COD_PROGRAMA, COD_PROCESO_PRE, COD_PROGRAMA_PRE, TIPO, OBSERVACION)
values (11, 'PRE_EJE_DEPURACION(2)', 11, 'PAS_BCP.PR_GEN_ENC_ASCII', 'F', 'El proceso PRE_EJE_DEPURACION(2) no debe de iniciar sin que finalice el PAS_BCP.PR_GEN_ENC_ASCII');
commit;