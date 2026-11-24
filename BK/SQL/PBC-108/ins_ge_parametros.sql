Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, OBSERVACION, PERMISO)
values ('CTA_EXC_SAL_PROMEDIO', 'CTAS. EXCLUIDAS ACT. SAL. PROMEDIO', 'GE_PAR_DINAMICOS', 'Cuentas que serán excluidas de actualización en el proceso: PRA_ACT_SAL_PROMEDIO', 'CIERRE-CIERRE DE MODULO');

commit;