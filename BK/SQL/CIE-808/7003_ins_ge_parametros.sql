begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/

Insert into GE_PARAMETROS (PARAMETRO,DESCRIPCION,TAB_RELACION,OBSERVACION,MODIFICABLE,VAL_DEFECTO)
values ('PRG_VAL_CONTROLES','EJEC PROC. CONTROL DE PROCESOS','GE_PAR_DINAMICOS','Activa la ejecucion de controles de procesos','S',null);

Insert into GE_PAR_DINAMICOS (PARAMETRO,VAL_PARAMETRO)
values ('PRG_VAL_CONTROLES','S');


COMMIT;
