begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('FEC_MAX_REV_TIG', 'FECHA MAXIMA REV. TIGO', 'GE_PAR_DINAMICOS', null, 'Se utiliza para definir la fecha maxima de reversion para tigo', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('COD_TRA_COM_TIGO_CM', 'COD TRANSACCION DEBCOM TIGO', 'GE_PAR_DINAMICOS', null, 'Codigo transaccion debito para tigo', null, null, 'N', 'S');

commit;