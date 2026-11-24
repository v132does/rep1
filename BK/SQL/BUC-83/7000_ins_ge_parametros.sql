begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('GRU_TRANS_BLOQ_CRED', 'TRANS. A SER BLOQUEADAS', 'GE_PAR_DINAMICOS', null, 'Grupo de transacciones utilizado para el bloqueo de operaciones de crédito a cuentas.', null, null, 'N', null);

insert into ge_parametros (parametro, descripcion, tab_relacion, referencia, observacion, modificable)
values ('BLO_CRE_AREAS', 'ÁREAS PARA BLOQUEO DE CRÉDITOS', 'BA_COD_REFERENCIAS', null, 'AREAS PARA BLOQUEO DE CRÉDITOS', 'S');

commit;
