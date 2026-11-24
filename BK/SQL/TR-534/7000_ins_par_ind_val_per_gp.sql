Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/
insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('IND_DEB_VAL_PER_GP','Validacion td gp por persona', 'GE_PAR_DINAMICOS', null, null, to_date('04-01-2024 14:59:20', 'dd-mm-yyyy hh24:mi:ss'), null, to_date('04-01-2024 14:59:20', 'dd-mm-yyyy hh24:mi:ss'), 'S-valida por persona, N- No valida', null, null, 'N', null);
insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, COD_SUB_MODALIDAD)
values ('IND_DEB_VAL_PER_GP', 'N', null, null, null, null, null, to_date('04-01-2024 15:04:25', 'dd-mm-yyyy hh24:mi:ss'), null, to_date('04-01-2024 15:04:25', 'dd-mm-yyyy hh24:mi:ss'), null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('NRO_BIN_TAR_CRE_BLACK', 'Nro Bin Credito Black Global', 'GE_PAR_DINAMICOS', null, 'PARRUA', to_date('08-08-2023 00:26:52', 'dd-mm-yyyy hh24:mi:ss'), 'PARRUA', to_date('08-08-2023 00:26:52', 'dd-mm-yyyy hh24:mi:ss'), 'Nro Bin Tarjeta Credito Black Global', null, null, 'N', null);
insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, COD_SUB_MODALIDAD)
values ('NRO_BIN_TAR_CRE_BLACK', '536090', null, null, null, null, 'MIGRA', to_date('17-09-2023 09:24:42', 'dd-mm-yyyy hh24:mi:ss'), 'MIGRA', to_date('17-09-2023 09:24:42', 'dd-mm-yyyy hh24:mi:ss'), null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('NRO_BIN_TAR_DEB_BLACK', 'Nro Bin Debito Black Global', 'GE_PAR_DINAMICOS', null, 'PARRUA', to_date('08-08-2023 00:26:52', 'dd-mm-yyyy hh24:mi:ss'), 'PARRUA', to_date('08-08-2023 00:26:52', 'dd-mm-yyyy hh24:mi:ss'), 'Nro Bin Tarjeta Debito Black Global', null, null, 'N', null);
insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, COD_SUB_MODALIDAD)
values ('NRO_BIN_TAR_DEB_BLACK', '529278', null, null, null, null, 'MIGRA', to_date('17-09-2023 09:24:42', 'dd-mm-yyyy hh24:mi:ss'), 'MIGRA', to_date('17-09-2023 09:24:42', 'dd-mm-yyyy hh24:mi:ss'), null);

commit;
