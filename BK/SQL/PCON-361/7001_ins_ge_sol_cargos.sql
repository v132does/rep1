begin  pre_ini_aplicacion;  pae_cnf.g_cod_modulo := 1; end; 
/
insert into ge_sol_cargos (cod_canal, cod_campana, cod_modulo, cod_modalidad, cod_transaccion, cod_ent_seguro, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion, cod_tip_canal)
values (null, null, 6, 668, 703, null, user, sysdate, user, sysdate, null);

commit;
