Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/
insert into ge_est_cuentas (COD_MODULO, COD_MODALIDAD, ESTADO, DESCRIPCION, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, ACTIVO)
values (5, 55, 'V', 'VENCIDA', 'AAGUILERA', to_date('29-04-2024 14:47:36', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('29-04-2024 14:47:36', 'dd-mm-yyyy hh24:mi:ss'), 'S');

insert into ge_est_cuentas (COD_MODULO, COD_MODALIDAD, ESTADO, DESCRIPCION, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, ACTIVO)
values (5, 55, 'C', 'CANCELADO', 'AAGUILERA', to_date('29-04-2024 14:47:36', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('29-04-2024 14:47:36', 'dd-mm-yyyy hh24:mi:ss'), 'S');

insert into ge_est_cuentas (COD_MODULO, COD_MODALIDAD, ESTADO, DESCRIPCION, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, ACTIVO)
values (5, 55, 'B', 'BLOQUEADO', 'AAGUILERA', to_date('29-04-2024 14:47:37', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('29-04-2024 14:47:37', 'dd-mm-yyyy hh24:mi:ss'), 'S');

insert into ge_est_cuentas (COD_MODULO, COD_MODALIDAD, ESTADO, DESCRIPCION, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, ACTIVO)
values (5, 55, 'A', 'ABIERTA', 'AAGUILERA', to_date('29-04-2024 14:47:37', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('29-04-2024 14:47:37', 'dd-mm-yyyy hh24:mi:ss'), 'S');

insert into ge_est_cuentas (COD_MODULO, COD_MODALIDAD, ESTADO, DESCRIPCION, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, ACTIVO)
values (5, 55, 'N', 'NORMAL', 'AAGUILERA', to_date('29-04-2024 14:47:37', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('29-04-2024 14:47:37', 'dd-mm-yyyy hh24:mi:ss'), 'S');

insert into ge_est_cuentas (COD_MODULO, COD_MODALIDAD, ESTADO, DESCRIPCION, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, ACTIVO)
values (5, 55, 'I', 'INACTIVA', 'AAGUILERA', to_date('29-04-2024 14:47:37', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('29-04-2024 14:47:37', 'dd-mm-yyyy hh24:mi:ss'), 'S');

commit;
