begin  pre_ini_aplicacion;  pae_cnf.g_cod_modulo := 1; end; 
/
insert into wf_gru_usuarios (cod_grupo, cod_usuario, estado, ver_otr_oficina, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion, exc_usuario)
values ('50', 'VGONZALEZ', 'A', 'S', user, sysdate, user, sysdate, 'N');

commit;
