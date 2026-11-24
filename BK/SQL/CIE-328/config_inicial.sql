begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/

Insert into GE_PARAMETROS (PARAMETRO,DESCRIPCION,TAB_RELACION,OBSERVACION,MODIFICABLE,VAL_DEFECTO)
values ('ACT_SALDOS_PARALLEL','EJEC PARALELA UPDATE SALDOS BATCH','GE_PAR_DINAMICOS','Activa la actualización de Saldos Batch en Paralelo en PRA_ACT_CUENTAS. PARALLEL_EXECUTE = Activa CHUNKS_BY_SQL por ROWID, NORMAL = Desactivado','S',null);

Insert into GE_PAR_DINAMICOS (PARAMETRO,VAL_PARAMETRO)
values ('ACT_SALDOS_PARALLEL','PARALLEL_EXECUTE');

Insert into GE_PARAMETROS (PARAMETRO,DESCRIPCION,TAB_RELACION,OBSERVACION,MODIFICABLE,VAL_DEFECTO)
values ('ACT_SALDOS_TAM_FRAG','TAM FRAGMENTO UPDATE SALDOS BATCH','GE_PAR_DINAMICOS','Cantidad de claves únicas (NRO_CUENTA) por fragmento (chunk) al realizar la actualización de Saldos Batch en Paralelo en PRA_ACT_CUENTAS','S',null);

Insert into GE_PAR_DINAMICOS (PARAMETRO,VAL_PARAMETRO)
values ('ACT_SALDOS_TAM_FRAG','5000');

Insert into GE_PARAMETROS (PARAMETRO,DESCRIPCION,TAB_RELACION,OBSERVACION,MODIFICABLE,VAL_DEFECTO)
values ('ACT_SALDOS_JOB_CANT','CANT JOBS PARA UPDATE SALDOS BATCH','GE_PAR_DINAMICOS','Cantidad de Jobs (workers) que se ejecutan al mismo tiempo para procesar los fragmentos (chunks) en la actualización de Saldos Batch en Paralelo en PRA_ACT_CUENTAS','S',null);

Insert into GE_PAR_DINAMICOS (PARAMETRO,VAL_PARAMETRO)
values ('ACT_SALDOS_JOB_CANT','5');

COMMIT;
