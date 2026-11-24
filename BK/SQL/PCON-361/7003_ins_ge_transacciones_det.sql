begin  pre_ini_aplicacion;  pae_cnf.g_cod_modulo := 1; end; 
/
insert into ge_transacciones_det (cod_transaccion, cod_modulo, cod_modalidad, cod_tra_hijo, cod_mod_hijo, cod_mad_hijo, nro_orden, obligatorio, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion)
values (1521, 6, 668, 517, 6, 668, 1, 'S', user, sysdate, user, sysdate);

insert into ge_transacciones_det (cod_transaccion, cod_modulo, cod_modalidad, cod_tra_hijo, cod_mod_hijo, cod_mad_hijo, nro_orden, obligatorio, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion)
values (703, 6, 668, 517, 6, 668, 1, 'S', user, sysdate, user, sysdate);

commit;
