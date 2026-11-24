begin  pre_ini_aplicacion;  pae_cnf.g_cod_modulo := 1; end; 
/
insert into ge_parametros (parametro, descripcion, tab_relacion, referencia, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion, observacion, pro_verificacion, permiso, modificable, val_defecto)
values ('DES_CRE_PRESTAMO', 'DESCRIPCION ACREDITACION PRESTAMOS', 'GE_PAR_DINAMICOS', null, user, sysdate, user, sysdate, 'Descripción del movimiento de acreditación del Préstamo', null, null, 'N', null);

commit;

insert into ge_par_dinamicos (parametro, val_parametro, cod_modulo, cod_modalidad, cod_oficina, cod_moneda, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion, cod_sub_modalidad)
values ('DES_CRE_PRESTAMO', 'Acreditación de Préstamo', null, null, null, null, user, sysdate, user, sysdate, null);

commit;
