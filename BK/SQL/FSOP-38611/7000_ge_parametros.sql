begin pre_ini_aplicacion;pae_cnf.g_cod_modulo:=1;end;
/
insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('SNP_FON_CTA_TRAN_BCP', 'CUENTA TRANSITORIA DEL BCP ', 'GE_PAR_DINAMICOS', null, 'BROLON', to_date('10-09-2024 23:35:52', 'dd-mm-yyyy hh24:mi:ss'), 'BROLON', to_date('10-09-2024 23:35:52', 'dd-mm-yyyy hh24:mi:ss'), 'Cuenta transitoria del BCP(fondeo transferencia al exterior)', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('SNP_FON_NRO_ABA_IBAN', 'NRO DE ABA FONDEO EXT.', 'GE_PAR_DINAMICOS', null, 'BROLON', to_date('10-09-2024 23:35:52', 'dd-mm-yyyy hh24:mi:ss'), 'BROLON', to_date('10-09-2024 23:35:52', 'dd-mm-yyyy hh24:mi:ss'), 'Nro de ABA o IBAN  (fondeo transferencia al exterior)', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('SNP_FON_BIC_CORRESPONSAL', 'BIC DEL CORRESPONSAL FONDEO EXT.', 'GE_PAR_DINAMICOS', null, 'BROLON', to_date('10-09-2024 23:35:52', 'dd-mm-yyyy hh24:mi:ss'), 'BROLON', to_date('10-09-2024 23:35:52', 'dd-mm-yyyy hh24:mi:ss'), 'BIC del corresponsal en el exterior del participante directo', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('SNP_FON_CTA_EXTERIOR', 'CTA PARA TRANSFERENCIA AL EXTERIOR ', 'GE_PAR_DINAMICOS', null, 'BROLON', to_date('10-09-2024 12:45:45', 'dd-mm-yyyy hh24:mi:ss'), 'BROLON', to_date('10-09-2024 13:18:44', 'dd-mm-yyyy hh24:mi:ss'), 'Nro de cuenta utilizado para transferencia al exterior', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('SNP_FON_COD_PER_BENEF', 'BANCO BENEFICIARIO FONDEO EXT.', 'GE_PAR_DINAMICOS', null, 'BROLON', to_date('10-09-2024 13:18:44', 'dd-mm-yyyy hh24:mi:ss'), 'BROLON', to_date('10-09-2024 13:18:44', 'dd-mm-yyyy hh24:mi:ss'), 'Codigo banco fondeo del exterior', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('SNP_FON_SWIFT_PER_BENEF', 'SWIFT BENEFICIARIO FONDEO EXT.', 'GE_PAR_DINAMICOS', null, 'BROLON', to_date('10-09-2024 13:18:44', 'dd-mm-yyyy hh24:mi:ss'), 'BROLON', to_date('10-09-2024 13:18:44', 'dd-mm-yyyy hh24:mi:ss'), 'Bic del banco fondeo del exterior', null, null, 'N', null);

commit;
