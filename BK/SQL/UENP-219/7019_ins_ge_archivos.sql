begin  pre_ini_aplicacion;  pae_cnf.g_cod_modulo := 1; end; 
/
insert into ge_archivos (referencia, archivo, nro_secuencia, for_fecha, usu_modificacion, fec_modificacion, usu_insercion, fec_insercion, lin_inicial, lin_final, separador, uti_loader, pos_proceso, pre_proceso)
values ('PR_PRE_CHE_ROGA', 'PR_PLA_CHE_ROGA.XLS', '1', null, user, sysdate, user, sysdate, 2, null, null, null, 'PRP_GEN_OFE_CHE_ROGA', null);

commit;

