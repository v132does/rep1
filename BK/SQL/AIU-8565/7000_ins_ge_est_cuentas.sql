begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into ge_est_cuentas (COD_MODULO, COD_MODALIDAD, ESTADO, DESCRIPCION,ACTIVO)
values (3, 34, 'A', 'ABIERTA', 'S');

insert into ge_est_cuentas (COD_MODULO, COD_MODALIDAD, ESTADO, DESCRIPCION,ACTIVO)
values (3, 34, 'B', 'BLOQUEO CUENTA', 'S');

insert into ge_est_cuentas (COD_MODULO, COD_MODALIDAD, ESTADO, DESCRIPCION,ACTIVO)
values (3, 34, 'C', 'CANCELADA', 'N');

insert into ge_est_cuentas (COD_MODULO, COD_MODALIDAD, ESTADO, DESCRIPCION,ACTIVO)
values (3, 34, 'N', 'NORMAL', 'S');

insert into ge_est_cuentas (COD_MODULO, COD_MODALIDAD, ESTADO, DESCRIPCION,ACTIVO)
values (3, 34, 'P', 'PEND.CANC.', 'S');

insert into ge_est_cuentas (COD_MODULO, COD_MODALIDAD, ESTADO, DESCRIPCION,ACTIVO)
values (3, 34, 'T', 'TOTALMENTE PAGADA', 'N');

insert into ge_est_cuentas (COD_MODULO, COD_MODALIDAD, ESTADO, DESCRIPCION,ACTIVO)
values (3, 34, 'V', 'VENCIDA', 'S');

insert into ge_est_cuentas (COD_MODULO, COD_MODALIDAD, ESTADO, DESCRIPCION,ACTIVO)
values (3, 34, 'X', 'VERIFICACION', 'S');

commit;
