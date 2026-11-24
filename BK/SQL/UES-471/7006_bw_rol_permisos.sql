begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end;
/
insert into bw_rol_permisos (COD_PERFIL, COD_TIP_MENSAJE, COD_PERSONA, CONSULTA, INGRESA, AUTORIZA, CAN_FIRMAS, ACTIVO)
values ('COMPLETO', '300', null, 'S', 'S', 'S', 1, 'S');

insert into bw_rol_permisos (COD_PERFIL, COD_TIP_MENSAJE, COD_PERSONA, CONSULTA, INGRESA, AUTORIZA, CAN_FIRMAS, ACTIVO)
values ('REGISTRA', '300', null, 'S', 'S', 'N', 1, 'S');

insert into bw_rol_permisos (COD_PERFIL, COD_TIP_MENSAJE, COD_PERSONA, CONSULTA, INGRESA, AUTORIZA, CAN_FIRMAS, ACTIVO)
values ('COMPLETO-FISICA', '300', null, 'S', 'S', 'S', 1, 'S');

insert into bw_rol_permisos (COD_PERFIL, COD_TIP_MENSAJE, COD_PERSONA, CONSULTA, INGRESA, AUTORIZA, CAN_FIRMAS, ACTIVO)
values ('AUTORIZA', '300', null, 'S', 'S', 'S', 1, 'S');

commit;
