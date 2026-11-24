begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/
insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA,OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('PRG_ACT_MOV_INI_JOB_CANT', 'CANT JOBS PARA INS GE_MOVIMIENTOS', 'GE_PAR_DINAMICOS', null,  'Cantidad de Jobs (workers) que se ejecutan al mismo tiempo para procesar los fragmentos (chunks) en la actualizacion de Cuentas en Paralelo en AH_CTA_VISTAS', null, null, 'S', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('PRG_ACT_MOV_INI_PARALLEL', 'EJEC PARALLEL INS. GE_MOVIMIENTOS', 'GE_PAR_DINAMICOS', null, 'Activa la inserción de Cuentas en Paralelo en  GE_MOVIMIENTOS', null, null, 'S', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('PRG_ACT_MOV_INI_TAM_FRAG', 'TAM FRAGMENTO INS. GE_MOVIMIENTOS', 'GE_PAR_DINAMICOS', null, 'Cantidad de registros por fragmento (chunk) al realizar la inserción en GE_MOVIMIENTOS', null, null, 'S', null);

commit;