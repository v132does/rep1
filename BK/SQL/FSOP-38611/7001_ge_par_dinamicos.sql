begin pre_ini_aplicacion;pae_cnf.g_cod_modulo:=1;end;
/
insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, COD_SUB_MODALIDAD)
values ('SNP_FON_CTA_EXTERIOR', '36243776', null, null, null, null, 'BROLON', to_date('10-09-2024 12:47:16', 'dd-mm-yyyy hh24:mi:ss'), 'BROLON', to_date('10-09-2024 13:19:52', 'dd-mm-yyyy hh24:mi:ss'), null);

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, COD_SUB_MODALIDAD)
values ('SNP_FON_COD_PER_BENEF', '8282535', null, null, null, null, 'BROLON', to_date('10-09-2024 13:19:52', 'dd-mm-yyyy hh24:mi:ss'), 'BROLON', to_date('10-09-2024 13:19:52', 'dd-mm-yyyy hh24:mi:ss'), null);

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, COD_SUB_MODALIDAD)
values ('SNP_FON_SWIFT_PER_BENEF', 'VISCPYPA', null, null, null, null, 'BROLON', to_date('10-09-2024 13:19:52', 'dd-mm-yyyy hh24:mi:ss'), 'BROLON', to_date('10-09-2024 13:19:52', 'dd-mm-yyyy hh24:mi:ss'), null);

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, COD_SUB_MODALIDAD)
values ('SNP_FON_CTA_TRAN_BCP', 'OUTG3001USD', null, null, null, null, 'BROLON', to_date('10-09-2024 23:37:43', 'dd-mm-yyyy hh24:mi:ss'), 'BROLON', to_date('10-09-2024 23:37:43', 'dd-mm-yyyy hh24:mi:ss'), null);

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, COD_SUB_MODALIDAD)
values ('SNP_FON_NRO_ABA_IBAN', '021000089', null, null, null, null, 'BROLON', to_date('10-09-2024 23:37:43', 'dd-mm-yyyy hh24:mi:ss'), 'BROLON', to_date('10-09-2024 23:37:43', 'dd-mm-yyyy hh24:mi:ss'), null);

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, COD_SUB_MODALIDAD)
values ('SNP_FON_BIC_CORRESPONSAL', 'CITIUS33', null, null, null, null, 'BROLON', to_date('10-09-2024 23:37:43', 'dd-mm-yyyy hh24:mi:ss'), 'BROLON', to_date('10-09-2024 23:37:43', 'dd-mm-yyyy hh24:mi:ss'), null);

commit;
