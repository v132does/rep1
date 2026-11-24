begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/
insert into ge_sub_modalidades (COD_MODULO, COD_MODALIDAD, COD_SUB_MODALIDAD, DESCRIPCION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (3, 34, 1, 'CDA DESMATERIALIZADO DIGITAL', null, 'RENCISO', to_date('10-07-2026 15:09:01', 'dd-mm-yyyy hh24:mi:ss'), 'RENCISO', to_date('10-07-2026 15:09:01', 'dd-mm-yyyy hh24:mi:ss'));

insert into ge_sub_modalidades (COD_MODULO, COD_MODALIDAD, COD_SUB_MODALIDAD, DESCRIPCION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (3, 34, 3, 'CDA DESMATERIALIZADO', null, 'RENCISO', to_date('10-07-2026 15:09:01', 'dd-mm-yyyy hh24:mi:ss'), 'RENCISO', to_date('10-07-2026 15:09:01', 'dd-mm-yyyy hh24:mi:ss'));

commit;
