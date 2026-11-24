begin
    pre_ini_aplicacion;
    pae_cnf.g_cod_modulo := 1;
end;
/
insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION, PRO_VERIFICACION, PERMISO)
values ('TAR_ACT_PAR_MAESTRO', 'ACT. PARALELISMO MAESTRO CTAS. GP', 'GE_PAR_DINAMICOS', null, 'Indica si se activa la funcionalidad de paralelismo durante la ejecucion del PRT_INS_MAE_CUE_GP.', null, null);

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, COD_SUB_MODALIDAD)
values ('TAR_ACT_PAR_MAESTRO', 'S', null, null, null, null,  null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION, PRO_VERIFICACION, PERMISO)
values ('TAR_VAL_NIV_PAR_MAESTRO', 'NIVEL DE EJECUCION PARALELISMO', 'GE_PAR_DINAMICOS', null, 'Indica el valor del nivel de paralelismo (jobs) que será ejecutado. Usado exclusivamente en el PRT_INS_MAE_CUE_GP', null, null);

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, COD_SUB_MODALIDAD)
values ('TAR_VAL_NIV_PAR_MAESTRO', '6', null, null, null, null,  null);

commit;
