begin  pre_ini_aplicacion;  pae_cnf.g_cod_modulo := 1; end; 
/
insert into wf_grupos (cod_grupo, descripcion, estado, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion)
values ('50', 'LEGALES', 'A', user, sysdate,  user, sysdate);

commit;
