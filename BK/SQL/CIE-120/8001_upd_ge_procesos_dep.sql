BEGIN pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; END;
/

update GE_PROCESOS_DEP
set COD_PROGRAMA = 'PRC_ELI_LIN_SOB_CANCELADO',  --> NRO_ORDEN 388
    OBSERVACION = 'El Programa PRG_TRA_HISTORICO debe garantizar su fin antes del inicio del Programa PAB_INV.PR_GEN_SAL_INVENTARIOS. Sin embargo, para garantizar Nivel de Paralelismo = 2, esta Dependencia de Fin queda configurada en el Programa PRC_ELI_LIN_SOB_CANCELADO',
    USU_MODIFICACION = user,
    FEC_MODIFICACION = sysdate
where COD_PROCESO = 11
  and COD_PROGRAMA = 'PAB_INV.PR_GEN_SAL_INVENTARIOS'
  and COD_PROCESO_PRE = 11
  and COD_PROGRAMA_PRE = 'PRG_TRA_HISTORICO'
  and TIPO = 'F';

COMMIT;
