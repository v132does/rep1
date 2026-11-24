begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end;
/
insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, OBSERVACION, MODIFICABLE, VAL_DEFECTO)
values ('PRG_TRA_NIV_PARALELISMO', 'NIVEL DE EJECUCION PARALELISMO', 'GE_PAR_DINAMICOS', 'Cantidad de Jobs (workers) que se ejecutan al mismo tiempo para procesar los fragmentos (chunks) en la inserción en Paralelo en el PRG_TRA_HISTORICO', 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, OBSERVACION, MODIFICABLE, VAL_DEFECTO)
values ('PRG_TRA_TAM_FRAG', 'CANTIDAD DE REGISTROS', 'GE_PAR_DINAMICOS', 'Cantidad de registros por fragmento (chunk) al realizar la inserción en Paralelo en el PRG_TRA_HISTORICO', 'N', null);

commit;
