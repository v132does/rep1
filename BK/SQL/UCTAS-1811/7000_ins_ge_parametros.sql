begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/
insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, OBSERVACION, MODIFICABLE)
values ('COD_SUB_MAD_SIN_PER', 'CODIGO SUBMODA NO PERMITIDAS BANKIT', 'GE_PAR_DINAMICOS', 'Este parametro sirve para registrar submodalidades no permitidas para el alta de cuentas desde bankitti', 'N');

commit;
