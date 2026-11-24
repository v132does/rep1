Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('IND_VAL_VIGIA', 'VALIDACION VIGIA', 'GE_PAR_DINAMICOS', null, 'Indica si se habilita validación vigia.', null, null, 'N', null);

commit;
