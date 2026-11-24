begin pre_ini_aplicacion;pae_cnf.g_cod_modulo:=1;end;
/
insert into it.ba_programas (cod_programa, descripcion, cod_tip_programa, cod_modulo, ubi_ejecutable, ubi_fisico, des_detallada, cod_herramienta, observacion, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion, ope_mod_cerrado, cod_pro_equivalente,  ubi_menu, ina_cierre)
values ('CMMODRBC', 'MODIFICACION DE ERRORES', 1, 4, 'Z:\GF10G\EXE', 'Z:\GF10G\FMB', 'Permite la Modificacion de los errores', null, null, user, sysdate, user, sysdate, 'N', null, 'Botón de Verificar errores', 'N');
/
commit;
