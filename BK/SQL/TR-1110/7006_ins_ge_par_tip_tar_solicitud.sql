Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/
insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, COD_SUB_MODALIDAD)
values ('TIP_TAR_SOLICITUD', 'S', 5, 55, null, 'GS', 'AAGUILERA', to_date('30-04-2024 10:53:20', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('30-04-2024 10:53:20', 'dd-mm-yyyy hh24:mi:ss'), 1);

commit;
