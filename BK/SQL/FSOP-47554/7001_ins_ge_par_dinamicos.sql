begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end; 
/
insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MONEDA)
values ('LIM_MTO_DIA_DEP_GRAL_PRO_WP', '999999999999999', 'GS');

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MONEDA)
values ('LIM_MTO_DIA_EXT_GRAL_PRO_WP', '999999999999999', 'GS');

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MONEDA)
values ('PAR_CAN_OPE_DEP_PRO_WP', '3', null);

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MONEDA)
values ('PAR_CAN_OPE_EXT_PRO_WP', '3', null);

commit;
