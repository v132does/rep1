begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/

insert into bw_rol_permisos (cod_perfil, cod_tip_mensaje, cod_persona, consulta, ingresa, autoriza, can_firmas, activo)
values ('COMPLETO', '301', null, 'S', 'S', 'S', 0, 'S');

insert into bw_rol_permisos (cod_perfil, cod_tip_mensaje, cod_persona, consulta, ingresa, autoriza, can_firmas, activo)
values ('COMPLETO', '302', null, 'S', 'S', 'S', 0, 'S');

insert into bw_rol_permisos (cod_perfil, cod_tip_mensaje, cod_persona, consulta, ingresa, autoriza, can_firmas, activo)
values ('COMPLETO', '303', null, 'S', 'S', 'S', 0, 'S');

commit;
