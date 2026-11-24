begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end; 
/
insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION, PRO_VERIFICACION, PERMISO)
values ('GE_VAL_NIV_PARALELISMO', 'NIVEL DE EJECUCION PARALELISMO', 'GE_PAR_DINAMICOS', null, 'Indica el valor del nivel de paralelismo (jobs) que será ejecutado. Usado exclusivamente en el PAP_CAT.PR_PRO_CAT_RES37', null, null);
/
insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION, PRO_VERIFICACION, PERMISO)
values ('GE_ACT_PARALEL_RES37', 'ACTIVAR PARALELISMO EN PAP_CAT', 'GE_PAR_DINAMICOS', null, 'Indica si se activa la funcionalidad de paralelismo durante la ejecucion del PAP_CAT.PR_PRO_CAT_RES37 del cierre operativo.', null, null);
/
commit;--2 registros
