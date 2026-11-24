begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/
insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, MODIFICABLE)
values ('SNP_CANT_MAX_MSJ_LOTE', 'CANTIDAD MAXIMA MENSAJE EN LOTE', 'GE_PAR_DINAMICOS', 'N');

commit;
