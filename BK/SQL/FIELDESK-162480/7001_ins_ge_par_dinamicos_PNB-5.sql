begin pre_ini_aplicacion;pae_cnf.g_cod_modulo := '1'; end;
/
insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, COD_SUB_MODALIDAD)
values ('SIB_LCR_FGD', '217428600', null, null, null, null, user, sysdate, user, sysdate, null);

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, COD_SUB_MODALIDAD)
values ('SIB_LCR_CAN_SALARIOS', '500', null, null, null, null, user, sysdate, user, sysdate, null);

commit;