begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end;
/
insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO)
values ('CAN_CUO_CAN_AHO_PRO', '3');

insert into ge_par_dinamicos(parametro, cod_modulo, cod_modalidad, val_parametro)
                     values('COD_TRA_CAR_FIJ_APR', 4,41,'2223');
insert into ge_par_dinamicos(parametro,cod_modulo, cod_modalidad, val_parametro)
                     values('COD_TRA_CAR_FIJ_APR', 3,31,'503'); 
insert into ge_par_dinamicos(parametro,cod_modulo, cod_modalidad, val_parametro)
                     values('COD_TRA_CAR_FIJ_APR', 3,334,'503'); 
insert into ge_par_dinamicos(parametro, cod_modulo, cod_modalidad, val_parametro)
                     values('COD_TRA_CAR_POR_APR', 4,41, '2223');
insert into ge_par_dinamicos(parametro, cod_modulo, cod_modalidad, val_parametro)
                     values('COD_TRA_CAR_POR_APR', 3,31, '503'); 
insert into ge_par_dinamicos(parametro, cod_modulo, cod_modalidad, val_parametro)
                     values('COD_TRA_CAR_POR_APR', 3,334, '503'); 
insert into ge_par_dinamicos(parametro,cod_modulo, cod_modalidad, val_parametro)
                     values('COD_TRA_CAR_TOT_APR', 3, 31, '503');
insert into ge_par_dinamicos(parametro,cod_modulo, cod_modalidad, val_parametro)
                     values('COD_TRA_CAR_TOT_APR', 3, 334, '503');
insert into ge_par_dinamicos(parametro,cod_modulo, cod_modalidad, val_parametro)
                     values('COD_TRA_CAR_TOT_APR', 4, 41, '2223');
insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, COD_SUB_MODALIDAD)
values ('MTO_MIN_CUO_AHO_PROGRAMADO', '10000', 3, 38, null, 'GS', null);

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, COD_SUB_MODALIDAD)
values ('MTO_MIN_CUO_AHO_PROGRAMADO', '5', 3, 38, null, 'USD', null);

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, COD_SUB_MODALIDAD)
values ('VTO_HAB_CUPON', 'S', 3, 38, null, null, null);
                                      
insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO)
values ('AHO_PRO_REFUERZO', 'N');

commit;
