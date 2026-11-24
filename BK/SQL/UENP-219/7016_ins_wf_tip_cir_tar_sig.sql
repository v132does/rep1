begin  pre_ini_aplicacion;  pae_cnf.g_cod_modulo := 1; end; 
/
insert into wf_tip_cir_tar_sig (cod_tip_circuito, cod_tip_tarea, cod_tip_tar_siguiente, descripcion, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion, tar_excepcion)
values (925, 1, 2, 'VERIFICACION DEL BORRADOR.', user, sysdate, user, sysdate, 'N');

insert into wf_tip_cir_tar_sig (cod_tip_circuito, cod_tip_tarea, cod_tip_tar_siguiente, descripcion, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion, tar_excepcion)
values (925, 2, 3, 'GESTIÓN DE FIRMA DE ESCRITURA.', user,sysdate, user,sysdate, 'N');

insert into wf_tip_cir_tar_sig (cod_tip_circuito, cod_tip_tarea, cod_tip_tar_siguiente, descripcion, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion, tar_excepcion)
values (925, 3, 4, 'FIRMA DE ESCRITURA FINALIZADA.', user,sysdate, user, sysdate, 'N');

commit;
