begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO)
values ('CC_ACT_REC_AUT', 'S');

insert into it.ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO)
values ('CAJ_COD_CAM_OPCION', '¿?');

insert into it.ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO)
values ('CAJ_COD_OPC', '777');

insert into it.ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO)
values ('CAJ_COD_OPC_CUSTOM', '888');

insert into it.ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO)
values ('COD_CAU_BLO_CTA_IF', '122');

insert into it.ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO)
values ('CAN_DIAS_BLOQUEO', '30');

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO)
values ('COD_CAU_INH_BLO_CTA', ',248,249,');

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO)
values ('FEC_INH_AUTOMATICA', '10/03/2025');

commit;  
