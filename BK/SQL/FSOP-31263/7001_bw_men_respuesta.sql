begin pre_ini_aplicacion;pae_cnf.g_cod_modulo:=1;end;
/
insert into bw_men_respuesta (NOMBRE, DES_MENSAJE, ERROR)
values ('332', 'Datos incorrectos en transferencia', 'S');

commit;
