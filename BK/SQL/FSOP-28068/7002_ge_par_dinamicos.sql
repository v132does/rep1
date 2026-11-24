begin pre_ini_aplicacion;pae_cnf.g_cod_modulo:=1;end;
/
insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MONEDA)
values ('BEPSA_CAN_MIN_USU_ENV', '1', null);

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MONEDA)
values ('BEPSA_CAN_MAX_USU_ENV', '10', null);

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MONEDA)
values ('PAGOPAR_CAN_MIN_USU_ENV', '1', null);

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MONEDA)
values ('PAGOPAR_CAN_MAX_USU_ENV', '10', null);

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MONEDA)
values ('TRANSFER_CAN_MIN_USU_ENV', '1', null);

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MONEDA)
values ('TRANSFER_CAN_MAX_USU_ENV', '10', null);

commit;
