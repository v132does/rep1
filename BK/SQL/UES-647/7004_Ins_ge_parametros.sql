begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('CTA_COM_TIGO', 'CUENTA COMISION TIGO CASH', 'GE_PAR_DINAMICOS', null, 'Numero de cuenta Comision de Tigo Cash', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('CTA_OPE_TIGO', 'CUENTA OPERATIVA TIGO CASH', 'GE_PAR_DINAMICOS', null, 'Numero de cuenta operativa de Tigo Cash', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('MTO_COM_TIGO', 'MONTO COMISION TIGO CASH', 'GE_PAR_DINAMICOS', null, 'Importe Comision de Tigo', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('MTO_MIN_TIGO', 'MONTO MINIMO TIGO', 'GE_PAR_DINAMICOS', null, 'Monto Minimo Compra de Minutos Tigo', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('COD_TRA_CRE_TIGO', 'COD TRANSACCION CRE TIGO', 'GE_PAR_DINAMICOS', null, 'Codigo transaccion credito para tigo', null, null, 'N', 'S');

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('COD_TRA_COM_TIGO', 'COD TRANSACCION COM TIGO', 'GE_PAR_DINAMICOS', null, 'Codigo transaccion Comision para tigo', null, null, 'N', 'S');

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('COD_TRA_DEB_TIGO', 'COD TRANSACCION DEB TIGO', 'GE_PAR_DINAMICOS', null, 'Codigo transaccion debito para tigo', null, null, 'N', 'S');

commit;
