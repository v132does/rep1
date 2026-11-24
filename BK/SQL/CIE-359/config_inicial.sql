begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/

Insert into GE_PARAMETROS (PARAMETRO,DESCRIPCION,TAB_RELACION,OBSERVACION,MODIFICABLE,VAL_DEFECTO)
values ('PAG_CIE_MODO_LOCK','MODO LOCK PACKAGE PAG_CIE','GE_PAR_DINAMICOS','Establece el modo de bloqueo como control global de concurrencia durante la ejecución de los Programas de un Proceso. OFF, X_MODE exclusivo','S',null);

Insert into GE_PAR_DINAMICOS (PARAMETRO,VAL_PARAMETRO)
values ('PAG_CIE_MODO_LOCK','X_MODE');

COMMIT;
