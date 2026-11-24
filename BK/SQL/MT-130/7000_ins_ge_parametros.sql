begin  pre_ini_aplicacion;  pae_cnf.g_cod_modulo := 1; end; 
/
insert into ge_parametros (parametro, descripcion, tab_relacion, referencia, observacion, pro_verificacion, permiso, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion)
values ('CJ_TRA_PAD_TED_TCD', 'COD TRANSACCION DE CARGA - TED', 'GE_PAR_DINAMICOS', null, 'Conf de Cod Transaccion TED para carga de efectivo', null, null, user, sysdate, user, sysdate);
insert into ge_parametros (parametro, descripcion, tab_relacion, referencia, observacion, pro_verificacion, permiso, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion)
values ('CJ_TRA_HIJ_TED_TRC', 'COD TRANSACCION HIJO DE CARGA - TED','GE_PAR_DINAMICOS', null, 'Conf de Cod Transaccion hijo TED para carga de efectivo', null, null, user, sysdate, user, sysdate);
insert into ge_parametros (parametro, descripcion, tab_relacion, referencia, observacion, pro_verificacion, permiso, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion)
values ('CJ_TRA_HIJ_TED_TRD', 'COD TRANSACCION DE DESCARGA - TED', 'GE_PAR_DINAMICOS', null, 'Conf de Cod Transaccion hijo TED para descarga de efectivo', null, null, user, sysdate, user, sysdate);
insert into ge_parametros (parametro, descripcion, tab_relacion, referencia, observacion, pro_verificacion, permiso, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion)
values ('CJ_COD_TRA_TRD_TED', 'COD TRA EXT DES- TED', 'GE_PAR_DINAMICOS',null, 'Conf de Cod Transaccion Cta TED para descarga de efectivo', null, null, user, sysdate, user, sysdate);
insert into ge_parametros (parametro, descripcion, tab_relacion, referencia, observacion, pro_verificacion, permiso, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion)
values ('CJ_COD_TRA_TRC_TED', 'COD TRA DEP CAR - TED', 'GE_PAR_DINAMICOS', null, 'Conf de Cod Transaccion Cta TED para carga de efectivo', null, null, user, sysdate, user, sysdate);
insert into ge_parametros (parametro, descripcion, tab_relacion, referencia, observacion, pro_verificacion, permiso, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion)
values ('NRO_CTA_GS', 'NRO. CTA. PORTAVALOR EN GUARANIES', 'GE_PAR_ENTES', 'CD', 'Nro. de Cuenta de portavalores para operaciones de carga descarga en guaranies', null, null, user, sysdate, user, sysdate);
insert into ge_parametros (parametro, descripcion, tab_relacion, referencia, observacion, pro_verificacion, permiso, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion)
values ('NRO_CTA_US', 'NRO. CTA. PORTAVALOR EN DOLARES', 'GE_PAR_ENTES', 'CD', 'Nro. de Cuenta de portavalores para operaciones de carga descarga en dolares', null, null, user, sysdate, user, sysdate);
commit;
