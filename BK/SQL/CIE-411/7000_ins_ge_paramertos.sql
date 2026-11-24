begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/

Insert into GE_PARAMETROS (PARAMETRO,DESCRIPCION,TAB_RELACION,OBSERVACION,MODIFICABLE,VAL_DEFECTO)
values ('PRA_TRA_ATM_PARALLEL','EJEC PARALELA INSERT AH CTA NOC','GE_PAR_DINAMICOS','Activa la insersión de Cuentas en Paralelo en AH_CTA_VISTAS_NOC','S',null);

Insert into GE_PAR_DINAMICOS (PARAMETRO,VAL_PARAMETRO)
values ('PRA_TRA_ATM_PARALLEL','PARALLEL_EXECUTE');

Insert into GE_PARAMETROS (PARAMETRO,DESCRIPCION,TAB_RELACION,OBSERVACION,MODIFICABLE,VAL_DEFECTO)
values ('PRA_TRA_ATM_TAM_FRAG','TAM FRAGMENTO INSERT AH CTA NOC','GE_PAR_DINAMICOS','Cantidad de registros por fragmento (chunk) al realizar la inserción de Cuentas en Paralelo en AH_CTA_VISTAS_NOC','S',null);

Insert into GE_PAR_DINAMICOS (PARAMETRO,VAL_PARAMETRO)
values ('PRA_TRA_ATM_TAM_FRAG','50000');

Insert into GE_PARAMETROS (PARAMETRO,DESCRIPCION,TAB_RELACION,OBSERVACION,MODIFICABLE,VAL_DEFECTO)
values ('PRA_TRA_ATM_JOB_CANT','CANT JOBS PARA INSERT AH CTA NOC','GE_PAR_DINAMICOS','Cantidad de Jobs (workers) que se ejecutan al mismo tiempo para procesar los fragmentos (chunks) en la inserción de Cuentas en Paralelo en AH_CTA_VISTAS_NOC','S',null);

Insert into GE_PAR_DINAMICOS (PARAMETRO,VAL_PARAMETRO)
values ('PRA_TRA_ATM_JOB_CANT','5');

COMMIT;
