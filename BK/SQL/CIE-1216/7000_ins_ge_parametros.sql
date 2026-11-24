begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/
insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, OBSERVACION, MODIFICABLE)
values ('PRA_CON_TRA_LIMIT_LOTE', 'TAMAÑO DE LOTE A PROCESAR', 'GE_PAR_DINAMICOS', 'Tamaño de limite para el bulk collect de pra_con_transaccion', 'S');

commit;
