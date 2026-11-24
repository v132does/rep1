 begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/
insert into ge_est_cuentas (COD_MODULO, COD_MODALIDAD, ESTADO, DESCRIPCION, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, ACTIVO)
values (10, 123, 'I', 'ENVIADO', 'ACASCO', to_date('28-05-2024 10:59:13', 'dd-mm-yyyy hh24:mi:ss'), 'ACASCO', to_date('28-05-2024 10:59:13', 'dd-mm-yyyy hh24:mi:ss'), 'S');

commit;
