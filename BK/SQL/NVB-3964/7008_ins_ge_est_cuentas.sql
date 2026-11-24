begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into it.ge_est_cuentas (COD_MODULO, COD_MODALIDAD, ESTADO, DESCRIPCION, ACTIVO)
values (10, 149, 'C', 'VIGENTE', 'S');

insert into it.ge_est_cuentas (COD_MODULO, COD_MODALIDAD, ESTADO, DESCRIPCION, ACTIVO)
values (10, 149, 'E', 'REPO', 'S');

insert into it.ge_est_cuentas (COD_MODULO, COD_MODALIDAD, ESTADO, DESCRIPCION, ACTIVO)
values (10, 149, 'N', 'CANCELADA', 'S');

insert into it.ge_est_cuentas (COD_MODULO, COD_MODALIDAD, ESTADO, DESCRIPCION, ACTIVO)
values (10, 149, 'R', 'RIPEADO', 'S');

insert into it.ge_est_cuentas (COD_MODULO, COD_MODALIDAD, ESTADO, DESCRIPCION, ACTIVO)
values (10, 149, 'S', 'SOLICITADA', 'S');

insert into it.ge_est_cuentas (COD_MODULO, COD_MODALIDAD, ESTADO, DESCRIPCION, ACTIVO)
values (10, 149, 'X', 'VERIFICACION', 'S');
/
commit;
/