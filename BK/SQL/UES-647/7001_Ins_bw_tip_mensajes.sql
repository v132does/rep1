begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/

insert into bw_tip_mensajes (cod_tip_mensaje, descripcion, consulta, ingresa, autoriza, dir_mail, nom_funcion, interno, afe_web)
values ('301', 'TIGO CASH IN', 'S', 'S', 'S', null, null, 'N', 'S');

insert into bw_tip_mensajes (cod_tip_mensaje, descripcion, consulta, ingresa, autoriza, dir_mail, nom_funcion, interno, afe_web)
values ('302', 'TIGO CASH OUT', 'S', 'S', 'S', null, null, 'N', 'S');

insert into bw_tip_mensajes (cod_tip_mensaje, descripcion, consulta, ingresa, autoriza, dir_mail, nom_funcion, interno, afe_web)
values ('303', 'TIGO COMPRA DE MINUTOS', 'S', 'S', 'S', null, null, 'N', 'S');

commit;
