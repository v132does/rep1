begin  pre_ini_aplicacion;  pae_cnf.g_cod_modulo := 1; end; 
/
insert into ge_parametros (parametro, descripcion, tab_relacion, referencia, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion, observacion, pro_verificacion, permiso, modificable, val_defecto)
values ('FOG_CUO_DES_DOS_ANO', 'CUOTA DESDE PARA 1 AÑO', 'GE_PAR_DINAMICOS', null, user, sysdate, user, sysdate, 'Define la cuota desde para calculo de comision Fogapy desde 1 año', null, null, 'N', null);

insert into ge_parametros (parametro, descripcion, tab_relacion, referencia, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion, observacion, pro_verificacion, permiso, modificable, val_defecto)
values ('FOG_CUO_HAS_DOS_ANO', 'CUOTA HASTA PARA 2 AÑOS', 'GE_PAR_DINAMICOS', null, user, sysdate, user, sysdate, 'Define la cuota hasta para calculo de comision Fogapy hasta 2 años', null, null, 'N', null);

insert into ge_parametros (parametro, descripcion, tab_relacion, referencia, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion, observacion, pro_verificacion, permiso, modificable, val_defecto)
values ('FOG_CUO_DES_TRE_ANO', 'CUOTA DESDE PARA 3 AÑOS', 'GE_PAR_DINAMICOS', null, user, sysdate, user, sysdate, 'Define la cuota desde para calculo de comision Fogapy desde 3 años', null, null, 'N', null);

insert into ge_parametros (parametro, descripcion, tab_relacion, referencia, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion, observacion, pro_verificacion, permiso, modificable, val_defecto)
values ('FOG_CUO_HAS_TRE_ANO', 'CUOTA HASTA PARA 10 AÑOS', 'GE_PAR_DINAMICOS', null,user, sysdate, user, sysdate, 'Define la cuota hasta para calculo de comision Fogapy hasta 10 años', null, null, 'N', null);

insert into ge_parametros (parametro, descripcion, tab_relacion, referencia, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion, observacion, pro_verificacion, permiso, modificable, val_defecto)
values ('POR_COB_GAR_50', 'COBERTURA DE GARANTÍA DE HASTA 50%', 'GE_PAR_DINAMICOS', null,user, sysdate, user, sysdate, 'Establece la cobertura de garantía sobre el 50% del capital, utilizada en el cálculo de la comisión Fogapy', null, null, 'N', null);

insert into ge_parametros (parametro, descripcion, tab_relacion, referencia, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion, observacion, pro_verificacion, permiso, modificable, val_defecto)
values ('POR_COB_GAR_30', 'COBERTURA DE GARANTÍA DE HASTA 30%', 'GE_PAR_DINAMICOS', null,user, sysdate, user, sysdate, 'Establece la cobertura de garantía sobre el 30% del capital, utilizada en el cálculo de la comisión Fogapy', null, null, 'N', null);

insert into ge_parametros (parametro, descripcion, tab_relacion, referencia, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion, observacion, pro_verificacion, permiso, modificable, val_defecto)
values ('POR_APL_COM_FOG', 'PORCENTAJE APLICADO COMISION FOG', 'GE_PAR_DINAMICOS', null,user, sysdate, user, sysdate, 'Define el porcentaje aplicado como garantía en el cálculo de la comisión Fogapy.', null, null, 'N', null);

commit;

insert into ge_par_dinamicos (parametro, val_parametro, cod_modulo, cod_modalidad, cod_oficina, cod_moneda, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion, cod_sub_modalidad)
values ('FOG_CUO_DES_DOS_ANO', '1', null, null, null, null, user, sysdate, user, sysdate, null);

insert into ge_par_dinamicos (parametro, val_parametro, cod_modulo, cod_modalidad, cod_oficina, cod_moneda, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion, cod_sub_modalidad)
values ('FOG_CUO_HAS_DOS_ANO', '24', null, null, null, null, user, sysdate, user, sysdate, null);

insert into ge_par_dinamicos (parametro, val_parametro, cod_modulo, cod_modalidad, cod_oficina, cod_moneda, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion, cod_sub_modalidad)
values ('FOG_CUO_DES_TRE_ANO', '25', null, null, null, null, user, sysdate, user, sysdate, null);

insert into ge_par_dinamicos (parametro, val_parametro, cod_modulo, cod_modalidad, cod_oficina, cod_moneda, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion, cod_sub_modalidad)
values ('FOG_CUO_HAS_TRE_ANO', '120', null, null, null, null, user, sysdate, user, sysdate, null);

insert into ge_par_dinamicos (parametro, val_parametro, cod_modulo, cod_modalidad, cod_oficina, cod_moneda, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion, cod_sub_modalidad)
values ('POR_COB_GAR_50', '0,5', null, null, null, null, user, sysdate, user, sysdate, null);

insert into ge_par_dinamicos (parametro, val_parametro, cod_modulo, cod_modalidad, cod_oficina, cod_moneda, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion, cod_sub_modalidad)
values ('POR_COB_GAR_30', '0,3', null, null, null, null, user, sysdate, user, sysdate, null);

insert into ge_par_dinamicos (parametro, val_parametro, cod_modulo, cod_modalidad, cod_oficina, cod_moneda, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion, cod_sub_modalidad)
values ('POR_APL_COM_FOG', '1', null, null, null, null, user, sysdate, user, sysdate, null);

commit;
