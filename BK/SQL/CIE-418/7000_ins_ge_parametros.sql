begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end; 
/
insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION, PRO_VERIFICACION, PERMISO)
values ('GE_VAL_NIV_PARAL_ASI_TMP', 'NIVEL DE EJECUCION PARALELISMO', 'GE_PAR_DINAMICOS', null, 'Indica el valor del nivel de paralelismo (jobs) que será ejecutado. Usado exclusivamente en el PRG_GEN_ASI_CIE_TMP', null, null);
/
insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION, PRO_VERIFICACION, PERMISO)
values ('GE_ACT_PARAL_ASI_TMP', 'PARALLEL ACTIVO PRG_GEN_ASI_CIE_TMP', 'GE_PAR_DINAMICOS', null, 'Indica si se activa la funcionalidad de paralelismo durante la ejecucion del PRG_GEN_ASI_CIE_TMP del cierre operativo.', null, null);
/
commit;--2 registros
