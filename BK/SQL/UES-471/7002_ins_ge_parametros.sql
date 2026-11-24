begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end;
/
insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('COD_MAD_PADRE_DAS', 'MODALIDAD PADRE DAS', 'GE_PAR_DINAMICOS', null, 'Codigo Modalidad Padre para das', null, null, null, 'S');

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('COD_MOD_PADRE_DAS', 'MODULO PADRE DAS', 'GE_PAR_DINAMICOS', null, 'Codigo Modulo Padre para das', null, null, null, 'S');

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('COD_TRA_PADRE_DAS', 'COD TRANSACCION PADRE DAS', 'GE_PAR_DINAMICOS', null, 'Codigo transaccion Padre para das', null, null, null, 'S');

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('COD_TRA_DEB_DAS', 'COD TRANSACCION DEB DAS', 'GE_PAR_DINAMICOS', null, 'Codigo transaccion débito para das', null, null, null, 'S');

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('COD_TRA_CRE_DAS', 'COD TRANSACCION CRE DAS', 'GE_PAR_DINAMICOS', null, 'Codigo transaccion crédito para das', null, null, null, 'S');

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('COD_TRA_DEBCOM_DAS', 'COD TRANSACCION DEBCOM DAS', 'GE_PAR_DINAMICOS', null, 'Codigo transaccion débito comisión para das', null, null, null, 'S');

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('TASA_DEBCOM_DAS', 'TASA DEBCOM DAS', 'GE_PAR_ENTES', 'DA', 'Tasa deb. com. das %', null, null, null, 'S');

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('SER_ACTIVO_DAS', 'SERVICIO ACTIVO DAS', 'GE_PAR_ENTES', 'DA', 'Indica si el servicio esta activo', null, null, null, 'S');

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('TIENE_CON_DAS', 'TIENE CONTRATO DAS', 'GE_PAR_ENTES', 'DA', 'Indica si tiene contrato DAS', null, null, null, 'S');

commit;
