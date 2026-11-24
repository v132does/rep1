begin  pre_ini_aplicacion;  pae_cnf.g_cod_modulo := 1; end; 
/
insert into ge_causales (cod_causa, descripcion, tipo, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion)
values (926, 'BLOQUEO DE SALDOS DESEM. CHE ROGA', 'B', user, sysdate, user,sysdate);

commit;
