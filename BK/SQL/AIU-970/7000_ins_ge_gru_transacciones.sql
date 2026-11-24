begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/
insert into ge_gru_transacciones (cod_gru_transaccion, descripcion, condicion)
    values (91,'Excluir ctrol credito cta basica cuando proviene de ah prog.','I');
commit;
