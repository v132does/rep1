begin  pre_ini_aplicacion;  pae_cnf.g_cod_modulo := 1; end; 
/
insert into ge_parametros (parametro, descripcion, tab_relacion, referencia, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion, observacion, pro_verificacion, permiso, modificable, val_defecto)
values ('COD_MOD_CONTROL', 'MODALIDAD PARA CONTROL', 'GE_PAR_DINAMICOS', null, user, sysdate, user, sysdate, 'Se utiliza para validar modalidades en el control de gastos imputables en el calculo del TAE', null, null, 'N', null);

insert into ge_parametros (parametro, descripcion, tab_relacion, referencia, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion, observacion, pro_verificacion, permiso, modificable, val_defecto)
values ('COD_MOD_CONTROL2', 'MODALIDAD PARA CONTROL', 'GE_PAR_DINAMICOS', null, user, sysdate, user, sysdate, 'Se utiliza para controlar modalidades que replican calculo de gastos ADM', null, null, 'N', null);

insert into ge_parametros (parametro, descripcion, tab_relacion, referencia, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion, observacion, pro_verificacion, permiso, modificable, val_defecto)
values ('MOD_SUM_IVA', 'MODALIDAD SUMA IVA', 'GE_PAR_DINAMICOS', null, user, sysdate, user, sysdate, 'Se utiliza para identificar modalidades que suman iva se interes en cada cuota', null, null, 'N', null);

commit;

insert into ge_par_dinamicos (parametro, val_parametro, cod_modulo, cod_modalidad, cod_oficina, cod_moneda, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion, cod_sub_modalidad)
values ('COD_MOD_CONTROL', '602', 6, 602, null, null, user, sysdate, user, sysdate, null);

insert into ge_par_dinamicos (parametro, val_parametro, cod_modulo, cod_modalidad, cod_oficina, cod_moneda, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion, cod_sub_modalidad)
values ('COD_MOD_CONTROL', '663', 6, 663, null, null, user, sysdate, user, sysdate, null);

insert into ge_par_dinamicos (parametro, val_parametro, cod_modulo, cod_modalidad, cod_oficina, cod_moneda, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion, cod_sub_modalidad)
values ('COD_MOD_CONTROL', '634', 6, 634, null, null, user, sysdate, user, sysdate, null);

insert into ge_par_dinamicos (parametro, val_parametro, cod_modulo, cod_modalidad, cod_oficina, cod_moneda, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion, cod_sub_modalidad)
values ('COD_MOD_CONTROL', '661', 6, 661, null, null, user, sysdate, user, sysdate, null);

insert into ge_par_dinamicos (parametro, val_parametro, cod_modulo, cod_modalidad, cod_oficina, cod_moneda, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion, cod_sub_modalidad)
values ('COD_MOD_CONTROL', '872', 6, 872, null, null, user, sysdate, user, sysdate, null);

commit;

insert into ge_par_dinamicos (parametro, val_parametro, cod_modulo, cod_modalidad, cod_oficina, cod_moneda, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion, cod_sub_modalidad)
values ('COD_MOD_CONTROL2', '68', 6, 68, null, null, user, sysdate, user, sysdate, null);

insert into ge_par_dinamicos (parametro, val_parametro, cod_modulo, cod_modalidad, cod_oficina, cod_moneda, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion, cod_sub_modalidad)
values ('COD_MOD_CONTROL2', '673', 6, 673, null, null, user, sysdate, user, sysdate, null);

insert into ge_par_dinamicos (parametro, val_parametro, cod_modulo, cod_modalidad, cod_oficina, cod_moneda, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion, cod_sub_modalidad)
values ('COD_MOD_CONTROL2', '992', 6, 992, null, null, user, sysdate, user, sysdate, null);

insert into ge_par_dinamicos (parametro, val_parametro, cod_modulo, cod_modalidad, cod_oficina, cod_moneda, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion, cod_sub_modalidad)
values ('COD_MOD_CONTROL2', '994', 6, 994, null, null, user, sysdate, user, sysdate, null);

commit;
