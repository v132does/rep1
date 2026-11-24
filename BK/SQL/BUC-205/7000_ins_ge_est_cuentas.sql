begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into it.ge_est_cuentas (COD_MODULO, COD_MODALIDAD, ESTADO, DESCRIPCION, ACTIVO)
values (15, 153, 'N', 'NORMAL', 'S');

insert into it.ge_est_cuentas (COD_MODULO, COD_MODALIDAD, ESTADO, DESCRIPCION, ACTIVO)
values (15, 151, 'N', 'NORMAL', 'S');

commit;
